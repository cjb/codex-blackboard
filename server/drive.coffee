# helper functions to perform Google Drive operations

# Credentials
KEY = Meteor.settings.key or Assets.getBinary 'drive-key.pem.crypt'
if Meteor.settings.password?
  # Decrypt the JWT authentication key synchronously at startup
  KEY = Gapi.decrypt KEY, Meteor.settings.password
EMAIL = Meteor.settings.email or '571639156428@developer.gserviceaccount.com'
SCOPES = ['https://www.googleapis.com/auth/drive']

# Drive folder settings
ROOT_FOLDER_NAME = Meteor.settings.folder or "MIT Mystery Hunt 2014"
CODEX_ACCOUNT = 'zouchenuttall@gmail.com'
WORKSHEET_NAME = (name) -> "Worksheet: #{name}"

# Constants
GDRIVE_FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder'
GDRIVE_SPREADSHEET_MIME_TYPE = 'application/vnd.google-apps.spreadsheet'
XLSX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
MAX_RESULTS = 200
SPREADSHEET_TEMPLATE = Assets.getBinary 'spreadsheet-template.xlsx'

# fetch the API and authorize
drive = null
rootFolder = null
debug = {}

quote = (str) ->
  "'" + str.replace(/([\'\\])/g, '\\$1') + "'"

checkAuth = (type) ->
  return true if drive?
  console.warn "Skipping Google Drive operation:", type
  false

wrapCheck = (f, type) ->
  () ->
    return unless checkAuth type
    f.apply(this, arguments)

ensureFolder = (name, parent) ->
  # check to see if the folder already exists
  resp = Gapi.exec drive.children.list
    folderId: parent or 'root'
    q: "title=#{quote name}"
    maxResults: 1
  if resp.items.length > 0
    resource = resp.items[0]
  else
    # create the folder
    resource =
      title: name
      mimeType: GDRIVE_FOLDER_MIME_TYPE
    resource.parents = [id: parent] if parent
    resource = Gapi.exec drive.files.insert resource
  # give the new folder the right permissions
  ensurePermissions(resource.id)
  resource

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
  resp = Gapi.exec drive.permissions.list(fileId: id)
  perms.forEach (p) ->
    # does this permission already exist?
    exists = resp.items.some (pp) -> samePerm(p, pp)
    unless exists
      Gapi.exec drive.permissions.insert({fileId:id}, p)
  'ok'

createPuzzle = (name) ->
  folder = ensureFolder name, rootFolder
  # is the spreadsheet already there?
  spreadsheet = (Gapi.exec drive.children.list
    folderId: folder.id
    q: "title=#{quote WORKSHEET_NAME name} and mimeType=#{quote GDRIVE_SPREADSHEET_MIME_TYPE}"
    maxResults: 1
  ).items[0]
  unless spreadsheet?
    # create an new spreadsheet from our template
    spreadsheet =
      title: WORKSHEET_NAME name
      mimeType: XLSX_MIME_TYPE
      parents: [id: folder.id]
    spreadsheet = Gapi.exec(drive.files.insert(
      convert: true
      body: spreadsheet # this is only necessary due to bug in gapi, afaict
    , spreadsheet).withMedia(XLSX_MIME_TYPE, SPREADSHEET_TEMPLATE))
  ensurePermissions(spreadsheet.id)
  return {
    id: folder.id
    spreadId: spreadsheet.id
  }

findPuzzle = (name) ->
  resp = Gapi.exec drive.children.list
    folderId: rootFolder
    q: "title=#{quote name} and mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
    maxResults: 1
  folder = resp.items[0]
  return null unless folder?
  # look for spreadsheet
  resp = Gapi.exec drive.children.list
    folderId: folder.id
    q: "title=#{quote WORKSHEET_NAME name}"
    maxResults: 1
  return {
    id: folder.id
    spreadId: resp.items[0]?.id
  }

listPuzzles = ->
  results = []
  resp = {}
  loop
    resp = Gapi.exec drive.children.list
      folderId: rootFolder
      q: "mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
      maxResults: MAX_RESULTS
      pageToken: resp.nextPageToken
    Array.prototype.push.apply(results, resp.items)
    break unless resp.nextPageToken?
  results

renamePuzzle = (name, id, spreadId) ->
  Gapi.exec drive.files.patch({fileId: id}, {title: name})
  if spreadId?
    Gapi.exec drive.files.patch(
        {fileId: spreadId}, {title: WORKSHEET_NAME name}
    )
  'ok'

rmrfFolder = (id) ->
  loop
    resp = {}
    loop
      # delete subfolders
      resp = Gapi.exec drive.children.list
        folderId: id
        q: "mimeType=#{quote GDRIVE_FOLDER_MIME_TYPE}"
        maxResults: MAX_RESULTS
        pageToken: resp.nextPageToken
      resp.items.forEach (item) ->
        rmrfFolder item.id
      break unless resp.nextPageToken?
    loop
      # delete non-folder stuff
      resp = Gapi.exec drive.children.list
        folderId: id
        q: "mimeType!=#{quote GDRIVE_FOLDER_MIME_TYPE}"
        maxResults: MAX_RESULTS
        pageToken: resp.nextPageToken
      resp.items.forEach (item) ->
        Gapi.exec drive.files.delete(fileId: item.id)
      break unless resp.nextPageToken?
    # are we done? look for remaining items owned by us
    resp = Gapi.exec drive.children.list
      folderId: id
      q: "#{quote EMAIL} in owners"
      maxResults: 1
    break if resp.items.length is 0
  # folder empty; delete the folder and we're done
  Gapi.exec drive.files.delete(fileId: id)
  'ok'

deletePuzzle = (id) -> rmrfFolder(id)

# purge `rootFolder` and everything in it
purge = () -> rmrfFolder(rootFolder)

# Intialize APIs and load rootFolder
do ->
  try
    unless /^-----BEGIN RSA PRIVATE KEY-----/.test(KEY)
      throw "INVALID GOOGLE DRIVE KEY OR PASSWORD"
    jwt = new Gapi.apis.auth.JWT(EMAIL, null, KEY, SCOPES)
    jwt.credentials = Gapi.authorize(jwt);
    client = Gapi.exec Gapi.apis.discover('drive', 'v2')
    # record the API and auth info
    drive = client.drive
    Gapi.registerAuth jwt
    # Look up the root folder
    resource = ensureFolder ROOT_FOLDER_NAME
    console.log "Google Drive authorized and activated"
    rootFolder = resource.id
    # for debugging/development
    debug.drive = drive
    debug.jwt = jwt
    debug.rootFolder = rootFolder
  catch error
    console.warn "Error trying to retrieve drive API:", error
    console.warn "Google Drive integration disabled."
    drive = null

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
