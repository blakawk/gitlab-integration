{CompositeDisposable, File, Directory, TextEditor} = require 'atom'
path = require 'path'
StatusBarView = require './status-bar-view'
GitlabStatus = require './gitlab-status'

module.exports = AtomGitlab =
    config:
        gitlabHost:
            title: 'Gitlab host'
            description: 'Hostname of server where is stored gitlab'
            type: 'string'
            default: 'gitlab.com'

    consumeStatusBar: (statusBar) ->
        @statusBar = statusBar
        @statusBarView.onDisplay (view) =>
            this.statusBarTile = this.statusBar.addRightTile
                item: view, priority: -1

    updateRepository: () ->
        currentPane = atom.workspace.getActivePaneItem()
        currentPath = currentPane?.getPath?()
        [ currentProject, _ ] = atom.project.relativizePath(currentPath)
        if currentProject?
            console.log currentProject, path.join(currentProject, '.gitlab-ci.yml')
            new File(path.join(currentProject, '.gitlab-ci.yml'), false)
                .exists()
                .then((exists) ->
                    console.log exists, path.join(currentProject, '.gitlab-ci.yml')
                    if exists
                        atom.project.repositoryForDirectory(new Directory(
                            currentProject
                        )).then((repository) =>
                            if repository?
                                console.log repository
                                origin = repository.getOriginURL()
                                re = new RegExp(
                                    "^[^@]+@#{atom.config.get('gitlabHost')}"
                                )
                                console.log origin, re, re.test(origin)
                                if re.test(origin) and origin isnt this.origin
                                    this.origin = origin
                                    this.gitlab.newOrigin(origin)
                        )
                )


    activate: (state) ->
        @subscriptions = new CompositeDisposable
        @statusBarView = new StatusBarView
        @statusBarView.init
        @gitlab = new GitlabStatus @statusBarView
        atom.project.onDidChangePaths (paths) =>
            console.log paths
        atom.workspace.observeActivePaneItem (editor) =>
            if editor instanceof TextEditor
                @updateRepository()
                @subscriptions.add editor.onDidChangePath =>
                    @updateRepository()

    deactivate: ->
        @subscriptions.dispose
        @statusBarTile?.destroy
