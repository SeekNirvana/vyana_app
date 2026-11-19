package com.seeknirvana.vyana

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Item 108: the weekly backup's folder, kept the way Android allows.
 *
 * The folder used to be stored as a plain path from the picker. Android
 * hands out a document tree (a `content://` URI), and access to it lasts
 * only as long as the activity unless the app takes a persisted permission,
 * so the next week's run found the folder "no longer reachable". This picks
 * the tree with ACTION_OPEN_DOCUMENT_TREE, takes the persisted read/write
 * permission, and does every read and write through DocumentsContract.
 *
 * File work runs on one background thread; results come back on the main
 * thread, which is where Flutter wants them.
 */
class BackupFolderHandler(private val activity: Activity) {
    private var pendingPick: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "pick") {
            pick(result)
            return
        }
        val folder = call.argument<String>("folder")
        if (folder.isNullOrEmpty()) {
            result.error("bad_args", "No folder", null)
            return
        }
        val tree = Uri.parse(folder)
        when (call.method) {
            "reachable" -> background(result) { reachable(tree) }
            "list" -> background(result) { list(tree) }
            "write" -> {
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                if (name.isNullOrEmpty() || bytes == null) {
                    result.error("bad_args", "No name or bytes", null)
                } else {
                    background(result) { write(tree, name, bytes) }
                }
            }
            "delete" -> {
                val name = call.argument<String>("name")
                if (name.isNullOrEmpty()) {
                    result.error("bad_args", "No name", null)
                } else {
                    background(result) { delete(tree, name) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (error: Exception) {
                main.post { result.error("io", error.message ?: error.toString(), null) }
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A folder is already being chosen", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        try {
            activity.startActivityForResult(intent, PICK_REQUEST)
        } catch (error: ActivityNotFoundException) {
            pendingPick = null
            result.success(null)
        }
    }

    /** Returns true when [requestCode] was this handler's. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (error: SecurityException) {
            // A provider that will not let access outlive the activity is a
            // folder the weekly backup cannot use, so it is not offered.
            result.success(null)
            return true
        }
        result.success(uri.toString())
        return true
    }

    private fun reachable(tree: Uri): Boolean {
        val held = activity.contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isWritePermission
        }
        if (!held) return false
        return try {
            activity.contentResolver.query(
                childrenUri(tree),
                arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
                null,
                null,
                null
            )?.use { true } ?: false
        } catch (error: Exception) {
            false
        }
    }

    /** Display name → document id, for every file directly in the folder. */
    private fun children(tree: Uri): Map<String, String> {
        val out = mutableMapOf<String, String>()
        activity.contentResolver.query(
            childrenUri(tree),
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            ),
            null,
            null,
            null
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0) ?: continue
                val name = cursor.getString(1) ?: continue
                out[name] = id
            }
        }
        return out
    }

    private fun list(tree: Uri): List<String> = children(tree).keys.toList()

    private fun write(tree: Uri, name: String, bytes: ByteArray): Boolean {
        val resolver = activity.contentResolver
        val existing = children(tree)[name]
        val target = if (existing != null) {
            DocumentsContract.buildDocumentUriUsingTree(tree, existing)
        } else {
            DocumentsContract.createDocument(
                resolver,
                DocumentsContract.buildDocumentUriUsingTree(
                    tree,
                    DocumentsContract.getTreeDocumentId(tree)
                ),
                "application/octet-stream",
                name
            ) ?: throw IllegalStateException("The folder refused a new file")
        }
        // "wt": truncate, so a shorter file never keeps the tail of a longer one.
        resolver.openOutputStream(target, "wt")?.use { it.write(bytes) }
            ?: throw IllegalStateException("The file could not be opened")
        return true
    }

    private fun delete(tree: Uri, name: String): Boolean {
        val id = children(tree)[name] ?: return false
        return DocumentsContract.deleteDocument(
            activity.contentResolver,
            DocumentsContract.buildDocumentUriUsingTree(tree, id)
        )
    }

    private fun childrenUri(tree: Uri): Uri =
        DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree)
        )

    companion object {
        private const val CHANNEL = "vyana/backup_folder"
        private const val PICK_REQUEST = 2409
    }
}
