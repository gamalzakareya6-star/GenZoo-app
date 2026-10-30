/**
 * GenZoo - Google Drive uploader (Google Apps Script, free).
 *
 * The app sends a file here and the script saves it in YOUR Drive folder, then
 * returns a public "anyone with the link can view" URL.
 * Only signed-in GenZoo users are accepted (their Firebase ID token is checked).
 *
 * SETUP (once, signed in with the Google account that will own the files):
 * 1. Drive: create a folder (e.g. "GenZoo Uploads"). Open it and copy the id
 *    from the address: drive.google.com/drive/folders/<THIS_PART>
 * 2. Go to https://script.google.com -> New project -> delete the sample code,
 *    paste this whole file, and put the folder id in FOLDER_ID below. Save.
 * 3. Deploy -> New deployment -> type "Web app":
 *      Execute as:      Me
 *      Who has access:  Anyone
 *    Deploy, accept the permissions (Drive access), and copy the "Web app URL".
 * 4. In the GenZoo app (admin): Admin dashboard -> "إعداد رفع الملفات" and paste
 *    the Web app URL.
 * After you change this code later: Deploy -> Manage deployments -> edit ->
 * New version (the URL stays the same).
 */
var FOLDER_ID = 'PUT_YOUR_DRIVE_FOLDER_ID_HERE';
// Public Firebase web API key of the app (it is already inside the APK).
var FIREBASE_API_KEY = 'AIzaSyCyItoPA7NaBYck4-tdTMWvIvj6TIe8eG0';
var MAX_BYTES = 15 * 1024 * 1024; // 15 MB per file
// Lets the Telegram bot (GitHub Actions) save files without a Firebase login.
// Put the same long random text here and in the GitHub secret
// GENZOO_UPLOAD_SECRET. Leave the placeholder to disable this path.
var UPLOAD_SECRET = 'PUT_A_LONG_RANDOM_SECRET_HERE';

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);

    var uid = null;
    if (body.secret && UPLOAD_SECRET !== 'PUT_A_LONG_RANDOM_SECRET_HERE' && body.secret === UPLOAD_SECRET) {
      uid = 'telegram-bot';
    } else {
      uid = verifyToken_(body.idToken);
    }
    if (!uid) return json_({ ok: false, error: 'unauthorized' });

    var bytes = Utilities.base64Decode(body.data || '');
    if (!bytes.length) return json_({ ok: false, error: 'empty file' });
    if (bytes.length > MAX_BYTES) return json_({ ok: false, error: 'file too large' });

    var name = String(body.name || 'file').replace(/[\\\/:*?"<>|]/g, '_').slice(0, 120);
    var blob = Utilities.newBlob(bytes, body.mimeType || 'application/octet-stream', name);

    var file = DriveApp.getFolderById(FOLDER_ID).createFile(blob);
    file.setDescription('uploaded by ' + uid);
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);

    return json_({ ok: true, id: file.getId(), url: file.getUrl(), name: name, size: bytes.length });
  } catch (err) {
    return json_({ ok: false, error: String(err) });
  }
}

// Returns the Firebase uid for a valid ID token, otherwise null.
function verifyToken_(idToken) {
  if (!idToken) return null;
  var res = UrlFetchApp.fetch(
    'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' + FIREBASE_API_KEY,
    {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify({ idToken: idToken }),
      muteHttpExceptions: true
    }
  );
  if (res.getResponseCode() !== 200) return null;
  var users = JSON.parse(res.getContentText()).users;
  return users && users.length ? users[0].localId : null;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
