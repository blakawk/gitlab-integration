{CompositeDisposable, File, Directory, TextEditor} = require 'atom'
path = require 'path'
GitUrlParse = require 'git-url-parse'
StatusBarView = require './status-bar-view'
GitlabStatus = require './gitlab'
log = require './log'

class GitlabIntegration
    config:
        token:
            title: 'Gitlab API token'
            description: 'Token to access your Gitlab API'
            type: 'string'
            default: ''
        period:
            title: 'Polling period (ms)'
            description: 'The interval at which gitlab will be polled'
            minimum: 1000
            default: 5000
            type: 'integer'
        debug:
            title: 'Enable debug output in console'
            type: 'boolean'
            default: false

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
            if currentPath?
                [ currentProject, _ ] =
                    atom.project.relativizePath(currentPath)
            else
                currentProject = undefined
            log "-- path change"
            log "    - current:", @currentProject
            log "    - new:", currentProject
            log "    - projects:", @projects
            log "    - current path:", currentPath
            if currentProject isnt @currentProject
                log "     -> project changed to", @projects[currentProject]
                if @projects[currentProject]?
                    if @projects[currentProject] isnt "<unknown>"
                        @statusBarView.onProjectChange(
                            @projects[currentProject]
                        )
                    else
                        @statusBarView.onProjectChange(null)
                        @statusBarView.unknown(currentProject)
                else
                    if not currentProject? and currentPath?
                        project = new File(currentPath).getParent()
                        currentProject = project.getPath()
                        if not @projects[currentProject]?
                            atom.project.repositoryForDirectory(project)
                                .then((repos) =>
                                    @handleRepository(project, repos, true)
                                )
                        else
                            @statusBarView.onProjectChange(
                                @projects[currentProject]
                            )
                @currentProject = currentProject

    handleRepository: (project, repos, setCurrent) ->
        origin = repos?.getOriginURL()
        log "--- handle repository"
        log "     - project:", project
        log "     - repos:", project
        log "     - current:", setCurrent
        if origin?
            log "     - origin:", origin
            url = GitUrlParse(origin)
            log "     - url:", url
            if url?
                projectName = url.pathname.slice(1).replace(/\.git$/, '')
                log "     - name:", projectName
                @projects[project.getPath()] = projectName
                if url.port?
                    host = "#{url.resource}:#{url.port}"
                else
                    host = url.resource
                @gitlab.watch(host, projectName)
                if setCurrent?
                    @statusBarView.onProjectChange(projectName)
            else
                @projects[project.getPath()] = "<unknown>"
        else
            @projects[project.getPath()] = "<unknown>"

    handleProjects: (projects) ->
        Promise.all(
            projects.map(
                (project) =>
                    atom.project.repositoryForDirectory(project).then(
                        (repos) =>
                            @handleRepository(project, repos)
                            Promise.resolve()
                    )
            )
        ).then(=>
            if @projects[@currentProject] is "<unknown>"
                @statusBarView.unknown(@currentProject)
            else
                @statusBarView.onProjectChange(@projects[@currentProject])
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
        @handleProjects(atom.project.getDirectories())
        @subscriptions.add atom.project.onDidChangePaths (paths) =>
            @handleProjects(paths.map((path) => new Directory(path)))
        atom.workspace.observeActivePaneItem (editor) =>
            if editor instanceof TextEditor
                @onPathChange()
                @subscriptions.add editor.onDidChangePath =>
                    @onPathChange

    deactivate: ->
        @subscriptions.dispose()
        @gitlab?.deactivate()
        @statusBarView?.deactivate()
        @statusBarTile?.destroy()

module.exports = new GitlabIntegration
