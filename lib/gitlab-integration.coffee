{CompositeDisposable, File, Directory, TextEditor} = require 'atom'
path = require 'path'
StatusBarView = require './status-bar-view'
GitlabStatus = require './gitlab'

module.exports = GitlabIntegration =
    config:
        host:
            title: 'Gitlab API endpoint'
            description: 'Hostname of server where to access Gitlab API'
            type: 'string'
            default: 'gitlab.com'
        token:
            title: 'Gitlab API token'
            description: 'Token to access your Gitlab API'
            type: 'string'
            default: ''
        period:
            title: 'Polling period (ms)'
            description: 'The interval at which gitlab will be polled'
            minimum: 1000
            default: 1000
            type: 'integer'

    consumeStatusBar: (statusBar) ->
        @statusBar = statusBar
        @statusBarView.onDisplay =>
            @statusBarTile = @statusBar.addRightTile
                item: @statusBarView, priority: -1
        @statusBarView.onDispose =>
            @statusBarTile.destroy()

    updateRepository: () ->
        currentPane = atom.workspace.getActivePaneItem()
        if currentPane instanceof TextEditor
            currentPath = currentPane?.getPath?()
            [ currentProject, _ ] = atom.project.relativizePath(currentPath)
            if currentProject?
                new File(path.join(currentProject, '.gitlab-ci.yml'), false)
                    .exists()
                    .then((exists) =>
                        if exists
                            atom.project.repositoryForDirectory(new Directory(
                                currentProject
                            )).then((repository) =>
                                if repository?
                                    origin = repository.getOriginURL()
                                    host = atom.config.get(
                                        'gitlab-integration.host'
                                    )
                                    re = new RegExp("^[^@]+@#{host}")
                                    if re.test(origin) and origin isnt @origin
                                        @origin = origin
                                        @gitlab.newOrigin(origin)
                                    else if this.origin?
                                        @origin = null
                                        @gitlab.newOrigin(null)
                                else if @origin?
                                    @origin = null
                                    @gitlab.newOrigin(null)
                            )
                        else if @origin?
                            @origin = null
                            @gitlab.newOrigin(null)
                    )
            else if @origin?
                @origin = null
                @gitlab.newOrigin(null)

    activate: (state) ->
        @subscriptions = new CompositeDisposable
        @statusBarView = new StatusBarView
        @statusBarView.init()
        if not atom.config.get('gitlab-integration.token')
            atom.notifications.addInfo(
                "You likely forgot to configure your gitlab token",
                {dismissable: true}
            )
        @subscriptions.add atom.config.onDidChange 'gitlab-integration.host',
            => @updateRepository()
        @subscriptions.add atom.config.onDidChange 'gitlab-integration.token', => @updateRepository()
        @gitlab = new GitlabStatus @statusBarView
        atom.workspace.observeActivePaneItem (editor) =>
            if editor instanceof TextEditor
                @updateRepository()
                @subscriptions.add editor.onDidChangePath =>
                    @updateRepository()

    deactivate: ->
        @subscriptions.dispose()
        @gitlab?.deactivate()
        @statusBarView?.deactivate()
        @statusBarTile?.destroy()
