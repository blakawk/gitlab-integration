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

    onPathChange: ->
        currentPane = atom.workspace.getActivePaneItem()
        if currentPane instanceof TextEditor
            currentPath = currentPane?.getPath?()
            [ currentProject, _ ] = atom.project.relativizePath(currentPath)
            console.log 'project change', currentProject
            if currentProject isnt @currentProject
                @statusBarView.onProjectChange(currentProject)
                @currentProject = currentProject

    handleRepository: (project, repos) =>
        origin = repos.getOriginURL()
        host = atom.config.get(
            'gitlab-integration.host'
        )
        re = new RegExp("^[^@]+@gitlab.com:(?:(.*)\.git|(.*))$")
        if re.test(origin)
            projectName = re.exec(origin).filter((group) => group?)[1]
            @gitlab.watch(projectName)
            @projects[project] = projectName

    handleProjects: (projects) =>
        Promise.all(projects.map(
            (project) =>
                atom.project.repositoryForDirectory()
        )).then((repositories) =>
                console.log repositories
                repositories.forEach(
                    (repos) => @handleRepository(project, repos)
                )
        )

    activate: (state) ->
        @subscriptions = new CompositeDisposable
        @statusBarView = new StatusBarView
        @statusBarView.init()
        @gitlab = new GitlabStatus @statusBarView
        @projects = {}
        if not atom.config.get('gitlab-integration.token')
            atom.notifications.addInfo(
                "You likely forgot to configure your gitlab token",
                {dismissable: true}
            )
        @subscriptions.add atom.config.onDidChange 'gitlab-integration.host', =>
            @gitlab.deactivate()
            @gitlab = new GitlabStatus @statusBarView
            @handleProjects(atom.project.getDirectories())
        @handleProjects(atom.project.getDirectories())
        @subscriptions.add atom.project.onDidChangePaths @handleProjects
        atom.workspace.observeActivePaneItem (editor) =>
            if editor instanceof TextEditor
                @subscriptions.add editor.onDidChangePath =>
                    @onPathChange()

    deactivate: ->
        @subscriptions.dispose()
        @gitlab?.deactivate()
        @statusBarView?.deactivate()
        @statusBarTile?.destroy()
