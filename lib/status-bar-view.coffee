{CompositeDisposable} = require('atom')
log = require './log'

class StatusBarView extends HTMLElement
    init: ->
        @classList.add('status-bar-gitlab', 'inline-block')
        @activate()
        @currentProject = null
        @stages = {}
        @statuses = {}
        @tooltips = []
        @controller = null

    setController: (controller) =>
      @controller = controller

    activate: => @displayed = false
    deactivate: =>
        @disposeTooltips()
        @dispose() if @displayed

    onDisplay: (@display) ->
        if @displayed
            @display(@)

    onDispose: (@dispose) ->

    hide: =>
        @dispose() if @displayed
        @displayed = false

    show: =>
        if @display?
            @display(@) if not @displayed
        @displayed = true

    onProjectChange: (project) =>
        log "current project becomes #{project}"
        @currentProject = project
        if project?
            if @stages[project]?
                @update(project, @stages[project])
            else if @statuses[project]?
                @loading(project, @statuses[project])
            else
                @unknown(project)

    onStagesUpdate: (stages) =>
        log "new stages", stages
        @stages = stages
        if @stages[@currentProject]?
            @update(@currentProject, @stages[@currentProject])

    disposeTooltips: =>
        @tooltips.forEach((tooltip) => tooltip.dispose())
        @tooltips = []

    loading: (project, message) =>
        log "project #{project} loading with status '#{message}'"
        @statuses[project] = message
        if @currentProject is project
            @show()
            @disposeTooltips()
            status = document.createElement('div')
            status.classList.add('inline-block')
            icon = document.createElement('a')
            icon.classList.add('icon', 'icon-gitlab')
            icon.onclick =  (e) =>
                @controller.openGitlabCICD(project);
            @tooltips.push atom.tooltips.add icon, {
                title: "GitLab project #{project}"
            }
            span = document.createElement('span')
            span.classList.add('icon', 'icon-sync', 'icon-loading')
            @tooltips.push atom.tooltips.add(span, {
                title: message,
            })
            status.appendChild icon
            status.appendChild span
            @setchild(status)

    setchild: (child) =>
        if @children.length > 0
            @replaceChild child, @children[0]
        else
            @appendChild child

    update: (project, stages) =>
        log "updating stages of project #{project} with", stages
        @show()
        @disposeTooltips()
        status = document.createElement('div')
        status.classList.add('inline-block')
        icon = document.createElement('a')
        icon.classList.add('icon', 'icon-gitlab')
        icon.onclick =  (e) =>
            @controller.openGitlabCICD(project);
        @tooltips.push atom.tooltips.add icon, {
            title: "GitLab project #{project} #{stages[0]?.pipeline} on branch #{stages[0]?.jobs[0]?.ref}"
        }
        status.appendChild icon
        if stages.length is 0
            e = document.createElement('span')
            e.classList.add('icon', 'icon-question')
            @tooltips.push atom.tooltips.add e, {
                title: "no pipeline found"
            }
            status.appendChild e
        else
            icon.onclick =  (e) =>
                @controller.openPipeline(project, stages);

            allPipeline = document.createElement('span')
            allPipeline.classList.add('icon', 'icon-inbox')
            @tooltips.push atom.tooltips.add allPipeline, {
                title: "Open all pipeline selector"
            }
            allPipeline.onclick = (e) =>
              @controller.openAllPipelineSelector(project);
            status.appendChild allPipeline

            pipeline = document.createElement('span')
            pipeline.classList.add('icon', "gitlab-#{stages[0]?.pipelineStatus}")
            pipeline.innerHTML = "#{stages[0]?.pipeline} &nbsp;"
            pipeline.onclick = (e) =>
              @controller.openPipelineSelector(project);
            @tooltips.push atom.tooltips.add pipeline, {
                title: "Open branch pipeline selector"
            }
            status.appendChild pipeline

            stages.forEach((stage) =>
                failedJobs =  stage.jobs.filter( (job) ->  job.status is 'failed' )

                e = document.createElement('a')
                e.classList.add('icon', "gitlab-#{stage.status}")
                e.onclick =  (e) =>
                  @controller.openJobSelector(project, stage);
                @tooltips.push atom.tooltips.add e, {
                    title: "#{stage.name}: #{stage.status} | #{failedJobs.length} failed jobs out of #{stage.jobs.length} | Click to individually select a job's log to download."
                }
                status.appendChild e
                if failedJobs.length > 0
                  e = document.createElement('a')
                  e.classList.add('icon', "gitlab-artifact")
                  e.onclick =  (e) =>
                      @controller.openFailedLogs(project, stage.jobs);
                  @tooltips.push atom.tooltips.add e, {
                      title: "Download all failed logs (#{failedJobs.length}) from the stage #{stage.name}"
                  }
                  status.appendChild e
            )
        @setchild(status)

    unknown: (project) =>
        log "project #{project} is unknown"
        @statuses[project] = undefined
        if @currentProject is project
            @show()
            @disposeTooltips()
            status = document.createElement('div')
            status.classList.add('inline-block')
            span = document.createElement('span')
            span.classList.add('icon', 'icon-question')
            status.appendChild span
            @tooltips.push atom.tooltips.add(span, {
                title: "no GitLab project detected in #{project}"
            })
            @setchild(status)

module.exports = document.registerElement 'status-bar-gitlab',
    prototype: StatusBarView.prototype, extends: 'div'
