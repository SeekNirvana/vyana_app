import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../config/env_config.dart';
import '../state/solana_mobile_wallet_service.dart';
import 'ring_order_pricing.dart';
import 'ring_order_tx_data.dart';

class RingUsdcPaymentResult {
  const RingUsdcPaymentResult({
    required this.signature,
    required this.memo,
    this.refreshedAuthToken,
  });
  final String signature;
  final String memo;
  final String? refreshedAuthToken;
}

class RingUsdcPaymentException implements Exception {
  RingUsdcPaymentException(this.message, {this.canRetry = true});
  final String message;
  final bool canRetry;

  @override
  String toString() => message;
}

/// Builds ring checkout transactions (USDC buy or SOL register-interest + memo).
class RingUsdcPaymentService {
  static const walletTimeout = Duration(seconds: 20);
  SolanaClient? _client;

  SolanaClient get client {
    _client ??= SolanaClient(
      rpcUrl: Uri.parse(EnvConfig.solanaRpcUrl),
      websocketUrl: Uri.parse(
        EnvConfig.solanaRpcUrl.replaceFirst('https://', 'wss://'),
      ),
    );
    return _client!;
  }

  Future<RingUsdcPaymentResult> pay({
    required String walletAddress,
    required String authToken,
    required String? walletPackage,
    required RingOrderPricing pricing,
    required RingOrderTxData orderData,
    Duration timeout = walletTimeout,
  }) async {
    if (walletAddress.isEmpty) {
      throw RingUsdcPaymentException('Connect your Solana wallet first.');
    }
    if (authToken.isEmpty) {
      throw RingUsdcPaymentException('Wallet session expired. Reconnect.');
    }

    final memo = orderData.toMemo();
    if (memo.length > 566) {
      throw RingUsdcPaymentException(
        'Order details are too long. Shorten your message.',
      );
    }

    try {
      final payer = Ed25519HDPublicKey.fromBase58(walletAddress);
      final treasury =
          Ed25519HDPublicKey.fromBase58(RingOrderPricing.treasuryAddress);

      final transferInstruction = switch (pricing.asset) {
        RingPaymentAsset.sol => await _buildSolTransfer(
            payer: payer,
            treasury: treasury,
            lamports: pricing.amount,
          ),
        RingPaymentAsset.usdc => await _buildUsdcTransfer(
            payer: payer,
            treasury: treasury,
            amount: pricing.amount,
          ),
      };

      final blockhash = await client.rpcClient
          .getLatestBlockhash(commitment: Commitment.confirmed)
          .then((r) => r.value.blockhash);

      final message = Message(
        instructions: [
          transferInstruction,
          MemoInstruction(signers: [payer], memo: memo),
        ],
      );

      final placeholder = Signature(List.filled(64, 0), publicKey: payer);
      final tx = SignedTx(
        compiledMessage: message.compile(
          recentBlockhash: blockhash,
          feePayer: payer,
        ),
        signatures: [placeholder],
      );

      final signResult = await SolanaMobileWalletService.signAndSendTransactions(
        authToken: authToken,
        walletPackage: walletPackage,
        transactions: [Uint8List.fromList(tx.toByteArray().toList())],
        timeout: timeout,
      );
      if (signResult.signatures.isEmpty) {
        throw RingUsdcPaymentException(
          'Wallet did not complete the payment.',
        );
      }

      final signature =
          Signature(signResult.signatures.first, publicKey: payer).toBase58();
      return RingUsdcPaymentResult(
        signature: signature,
        memo: memo,
        refreshedAuthToken: signResult.refreshedAuthToken,
      );
    } on SolanaMobileWalletException catch (error) {
      throw RingUsdcPaymentException(error.message);
    } on RingUsdcPaymentException {
      rethrow;
    } on Object catch (error) {
      throw RingUsdcPaymentException('$error');
    }
  }

  Future<Instruction> _buildSolTransfer({
    required Ed25519HDPublicKey payer,
    required Ed25519HDPublicKey treasury,
    required int lamports,
  }) async {
    final balance = await client.rpcClient.getBalance(
      payer.toBase58(),
      commitment: Commitment.confirmed,
    );
    final needed = lamports + 5000;
    if (balance.value < needed) {
      throw RingUsdcPaymentException(
        'Insufficient SOL balance for ${RingOrderPricing.interestSol} SOL.',
      );
    }

    return SystemInstruction.transfer(
      fundingAccount: payer,
      recipientAccount: treasury,
      lamports: lamports,
    );
  }

  Future<Instruction> _buildUsdcTransfer({
    required Ed25519HDPublicKey payer,
    required Ed25519HDPublicKey treasury,
    required int amount,
  }) async {
    final mint =
        Ed25519HDPublicKey.fromBase58(RingOrderPricing.usdcMintMainnet);

    final hasSender = await client.hasAssociatedTokenAccount(
      owner: payer,
      mint: mint,
      commitment: Commitment.confirmed,
    );
    if (!hasSender) {
      throw RingUsdcPaymentException(
        'No USDC account found. Add USDC to your wallet first.',
      );
    }

    final hasRecipient = await client.hasAssociatedTokenAccount(
      owner: treasury,
      mint: mint,
      commitment: Commitment.confirmed,
    );
    if (!hasRecipient) {
      throw RingUsdcPaymentException(
        'Treasury USDC account is not ready. Try again later.',
      );
    }

    try {
      final balance = await client.getTokenBalance(
        owner: payer,
        mint: mint,
        commitment: Commitment.confirmed,
      );
      if (int.parse(balance.amount) < amount) {
        throw RingUsdcPaymentException(
          'Insufficient USDC balance for checkout.',
        );
      }
    } on RingUsdcPaymentException {
      rethrow;
    } on Object {
      // Balance lookup is best-effort.
    }

    final senderAta =
        await findAssociatedTokenAddress(owner: payer, mint: mint);
    final recipientAta =
        await findAssociatedTokenAddress(owner: treasury, mint: mint);

    return TokenInstruction.transfer(
      source: senderAta,
      destination: recipientAta,
      owner: payer,
      amount: amount,
    );
  }
}

final ringUsdcPaymentServiceProvider = Provider<RingUsdcPaymentService>(
  (ref) => RingUsdcPaymentService(),
);