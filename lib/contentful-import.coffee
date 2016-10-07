ContentfulImportView = require './contentful-import-view'
{CompositeDisposable} = require 'atom'
{Directory} = require 'atom'
{File} = require 'atom'

module.exports = ContentfulImport =
  contentfulImportView: null
  modalPanel: null
  subscriptions: null
  config:
    accessToken:
      type: 'string',
      default: ''
    spaceID:
      type: 'string',
      default: ''
    directory:
      type: 'string',
      default: ''
    contentType:
      type: 'string',
      default: ''

  activate: (state) ->
    @contentfulImportView = new ContentfulImportView(state.contentfulImportViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @contentfulImportView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'contentful-import:import': => @import()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @contentfulImportView.destroy()

  serialize: ->
    contentfulImportViewState: @contentfulImportView.serialize()

  import: ->
    contentful = require 'contentful-management'
    scandir = require 'sb-scandir'
    path = require 'path'

    client = new contentful.createClient({
      accessToken: atom.config.get('contentful-import.accessToken')
    })

    client.getSpace(atom.config.get('contentful-import.spaceID'))
    .then((space) ->
      workspaceDir = atom.project.getDirectories()
      for subDirectory in workspaceDir
      # TODO: Maybe factor this in better with Atom APIS? Too much duplication?

        scandir(subDirectory.path + '/' + atom.config.get('contentful-import.directory'), true).then (files) ->
          filteredFiles = files.filter (file) -> path.extname(file) is '.md'
          filteredFiles = files.map (file) -> path.relative(subDirectory.path, file)

          for file in filteredFiles
            fileType = file.split('.').pop()
            if fileType == 'md'
              item = subDirectory.getFile(file)
              item.read(true)
              .then ((content) ->

                # TODO: Very Contentful Specific, best replaced
                start_pos = content.indexOf('page: :') + 7
                end_pos = content.indexOf('---',start_pos)
                articleTitle = content.substring(start_pos,end_pos)

                entryData =
                  "fields":
                    "title":
                      "en-US": articleTitle
                    "body":
                      "en-US": content

                space.createEntry(atom.config.get('contentful-import.contentType'), entryData)
                .then ((entry) ->
                  console.log(entry)
                )
                .catch((error) ->
                  console.log(error)
                )
              )

    )

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
      @modalPanel.show()