# helper functions to perform Google Drive operations
_when = Google.when # import

# Credentials
KEY = Meteor.settings.key or Assets.getBinary 'drive-key.pem.crypt'
if Meteor.settings.password?
  # Decrypt the JWT authentication key synchronously at startup
  KEY = Google.decrypt KEY, Meteor.settings.password
EMAIL = Meteor.settings.email or '571639156428@developer.gserviceaccount.com'
SCOPES = ['https://www.googleapis.com/auth/drive']

# Drive folder settings
ROOT_FOLDER_NAME = Meteor.settings.folder or "MIT Mystery Hunt 2014"
CODEX_ACCOUNT = 'zouchenuttall@gmail.com'
WORKSHEET_NAME = (name) -> "Worksheet: #{name}"

# Constants
GDRIVE_FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder'
MAX_RESULTS = 200

# fetch the API and authorize
drive = null
rootFolder = null
debug = {}

# XXX turn this into a sync operation at startup using Meteor._wrapAsync
unless /^-----BEGIN RSA PRIVATE KEY-----/.test(KEY)
  console.warn "INVALID GOOGLE DRIVE KEY"
else
  jwt = new Google.apis.auth.JWT(EMAIL, null, KEY, SCOPES)
  jwt.authorize (err,result) ->
    if err
      console.warn "Error trying to authorize Google Drive", err
      return
    jwt.credentials = result
    (Google.exec Google.apis.discover('drive', 'v2')).then (client) ->
      # Look up the root folder
      Google.registerAuth jwt
      drive = client.drive
      ensureFolder ROOT_FOLDER_NAME
    .then (resource) ->
      console.log "Google Drive authorized and activated"
      rootFolder = resource.id
      # for debugging/development
      debug.drive = drive
      debug.jwt = jwt
      debug.rootFolder = rootFolder
    .otherwise (err) ->
      console.warn "Error trying to retrieve drive API", err
      drive = null
    .done()

quote = (str) ->
  "'" + str.replace(/([\'\\])/g, '\\$1') + "'"

checkAuth = (type) ->
  return true if drive?
  console.warn "Skipping Google Drive operation:", type
  false

wrapCheck = (f, type) ->
  () ->
    return _when.reject("noauth: #{type}") unless checkAuth type
    f.apply(this, arguments)

ensureFolder = (name, parent) ->
  # check to see if the folder already exists
  Google.exec(drive.children.list(
    folderId: parent or 'root'
    q: "title=#{quote name}"
    maxResults: 1
  )).then( (resp) ->
    return resp.items[0] if resp.items.length > 0
    # create the folder
    resource =
      title: name
      mimeType: GDRIVE_FOLDER_MIME_TYPE
    resource.parents = [id: parent] if parent
    Google.exec(drive.files.insert resource)
  ).then( (resource) ->
    # give the new folder the right permissions
    ensurePermissions(resource.id).then () -> resource
  )

samePerm = (p, pp) ->
  p.withLink is pp.withLink and \
  p.role is pp.role and \
  p.type is pp.type and \
  (unless p.type is 'anyone' then (p.value is pp.value) else true)

ensurePermissions = (id) ->
  # give permissions to both anyone with link and to the primary
  # service acount.  the service account must remain the owner in
  # order to be able to rename the folder
  perms = [
    # edit permissions to codex account
    withLink: false
    role: 'writer'
    type: 'user'
    value: CODEX_ACCOUNT
  ,
    # edit permissions for anyone with link
    withLink: true
    role: 'writer'
    type: 'anyone'
  ]
  (Google.exec drive.permissions.list(fileId: id)).then (resp) ->
    _when.all perms.map (p) ->
      # does this permission already exist?
      exists = resp.items.some (pp) -> samePerm(p, pp)
      unless exists
        return Google.exec drive.permissions.insert({fileId:id}, p)
  .then () -> 'ok'

createPuzzle = (name) ->
  (ensureFolder name, rootFolder).then (folder) ->
    # create an empty spreadsheet
    spreadsheet =
      title: WORKSHEET_NAME name
      mimeType: 'application/vnd.google-apps.spreadsheet'
      parents: [id: folder.id]
    Google.exec(drive.files.insert(spreadsheet)).then (spreadsheet) ->
      ensurePermissions(spreadsheet.id).then () ->
        id: folder.id
        alternateLink: folder.alternateLink
        spreadId: spreadsheet.id

findPuzzle = (name) ->
  folder = null
  (Google.exec drive.children.list
    folderId: rootFolder
    q: "title=#{quote name} and mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
    maxResults: 1
  ).then (resp) ->
    folder = resp.items[0]
    # look for spreadsheet
    if folder? then Google.exec drive.children.list
      folderId: folder.id
      q: "title=#{quote WORKSHEET_NAME name}"
      maxResults: 1
  .then (resp) ->
    id: folder?.id
    spreadId: if resp? then resp.items[0]?.id

listPuzzles = () ->
  results = []
  getsome = (pageToken) ->
    (Google.exec drive.children.list
      folderId: rootFolder
      q: "mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
      maxResults: MAX_RESULTS
      pageToken: pageToken
    ).then (resp) ->
      Array.prototype.push.apply(results, resp.items)
      if resp.nextPageToken?
        getsome(resp.nextPageToken)
  getsome().then () ->
    results

renamePuzzle = (name, id, spreadId) ->
  (Google.exec drive.files.patch({fileId: id}, {title: name})).then () ->
    if spreadId?
      Google.exec drive.files.patch(
        {fileId: spreadId}, {title: WORKSHEET_NAME name}
      )
  .then () -> 'ok'

rmrfFolder = (id) ->
  [numfolders,numfiles] = [0,0]
  # delete subfolders
  (Google.exec drive.children.list
    folderId: id
    q: "mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
    maxResults: MAX_RESULTS
  ).then (resp) ->
    numfolders = resp.items.length
    _when.all resp.items.map (item) ->
      rmrfFolder item.id
  .then () ->
    # delete non-folder stuff
    Google.exec drive.children.list
      folderId: id
      q: "mimeType!=#{quote GDRIVE_FOLDER_MIME_TYPE}"
      maxResults: MAX_RESULTS
  .then (resp) ->
    numfiles = resp.items.length
    _when.all resp.items.map (item) ->
      Google.exec drive.files.delete(fileId: item.id)
  .then () ->
    if numfiles is 0 and numfolders is 0
      # folder empty; delete the folder and we're done
      Google.exec drive.files.delete(fileId: id)
    else
      # check for more files/folders
      rmrfFolder id

deletePuzzle = (id) -> rmrfFolder(id)

# purge `rootFolder` and everything in it
purge = () -> rmrfFolder(rootFolder)

# exports
share.drive =
  # debugging/devel
  debug: debug
  ensureFolder: ensureFolder
  ensurePermissions: ensurePermissions
  # main stuff
  createPuzzle: wrapCheck createPuzzle, 'createPuzzle'
  deletePuzzle: wrapCheck deletePuzzle, 'deletePuzzle'
  renamePuzzle: wrapCheck renamePuzzle, 'renamePuzzle'
  listPuzzles: wrapCheck listPuzzles, 'listPuzzles'
  findPuzzle: wrapCheck findPuzzle, 'findPuzzle'
  purge: wrapCheck purge, 'purge'
