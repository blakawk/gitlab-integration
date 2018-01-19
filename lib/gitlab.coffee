request = require 'request-promise-native'
log = require './log'

class GitlabStatus
    constructor: (@view, @timeout=null, @projects={}, @pending=[], @jobs={}) ->
        @token = atom.config.get('gitlab-integration.token')
        @period = atom.config.get('gitlab-integration.period')
        @updating = {}
        @watchTimeout = null

    fetch: (host, q, paging=false) ->
        log " -> fetch '#{q}' from '#{host}'"
        @get("https://#{host}/api/v4/#{q}").then((res) =>
            log " <- ", res
            if res.headers['x-next-page']
                if paging
                    log " -> retrieving #{res.headers['x-total-pages']} pages"
                    Promise.all(
                        [res.body].concat(
                            new Array(
                                parseInt(res.headers['x-total-pages']) - 1,
                            ).fill(0).map(
                                (dum, i) =>
                                    log " -> page #{i + 2}"
                                    @get(
                                        "https://#{host}/api/v4/#{q}" +
                                        (if q.includes('?') then '&' else '?') +
                                        "per_page=" + res.headers['x-per-page'] +
                                        "&page=#{i+2}"
                                    ).then((page) =>
                                        log "     <- page #{i + 2}", page
                                        page.body
                                    ).catch((error) =>
                                        console.error "cannot fetch page #{i + 2}", error
                                        Promise.resolve([])
                                    )
                            )
                        )
                    ).then((all) =>
                        Promise.resolve(all.reduce(
                            (all, one) =>
                                all.concat(one)
                            , [])
                        )
                    )
                else
                    log " -> ignoring paged output for #{q}"
                    res.body
            else
                res.body
        )

    get: (url) ->
        request({
            method: 'GET',
            uri: url,
            headers: {
                "PRIVATE-TOKEN": @token,
            },
            resolveWithFullResponse: true,
            json: true,
        })

    watch: (host, projectPath, repos) ->
        projectPath = projectPath.toLowerCase()
        if not @projects[projectPath]? and not @updating[projectPath]?
            @updating[projectPath] = false
            @view.loading projectPath, "loading project..."
            @fetch(host, "projects?membership=yes", true).then(
                (projects) =>
                    log "received projects from #{host}", projects
                    if projects?
                        project = projects.filter(
                            (project) =>
                                project.path_with_namespace.toLowerCase() is
                                    projectPath
                        )[0]
                        if project?
                            @projects[projectPath] = { host, project, repos }
                            @update()
                        else
                            @view.unknown(projectPath)
                    else
                        @view.unknown(projectPath)
            ).catch((error) =>
                @updating[projectPath] = undefined
                console.error "cannot fetch projects from #{host}", error
                @view.unknown(projectPath)
            )

    schedule: ->
        @timeout = setTimeout @update.bind(@), @period

    update: ->
        @pending = Object.keys(@projects).slice()
        @updatePipelines()

    updatePipelines: ->
        Object.keys(@projects).map(
            (projectPath) =>
                { host, project, repos } = @projects[projectPath]
                if project? and project.id? and not @updating[projectPath]
                    @updating[projectPath] = true
                    ref = repos?.getShortHead?()
                    if ref?
                        log "project #{project} ref is #{ref}"
                        ref = "?ref=#{ref}"
                    else
                        ref = ""
                    if not @jobs[projectPath]?
                        @view.loading(projectPath, "loading pipelines...")
                    @fetch(host, "projects/#{project.id}/pipelines#{ref}").then(
                        (pipelines) =>
                            log "received pipelines from #{host}/#{project.id}", pipelines
                            if pipelines.length > 0
                                @updateJobs(host, project, pipelines[0])
                            else
                                @onJobs(project, [])
                    ).catch((error) =>
                        console.error "cannot fetch pipelines for project #{projectPath}", error
                        @endUpdate(project)
                    )
        )

    endUpdate: (project) ->
        log "project #{project} update end"
        @updating[project] = false
        @pending = @pending.filter((pending) => pending isnt project)
        if @pending.length is 0
            @view.onStagesUpdate(@jobs)
            @schedule()
        @jobs[project.path_with_namespace]

    updateJobs: (host, project, pipeline) ->
        if not @jobs[project.path_with_namespace]?
            @view.loading(project.path_with_namespace, "loading jobs...")
        @fetch(host, "projects/#{project.id}/" + "pipelines/#{pipeline.id}/jobs", true)
        .then((jobs) =>
            log "received jobs from #{host}/#{project.id}/#{pipeline.id}", jobs
            if jobs.length is 0
                @onJobs(project, [
                    name: pipeline.name
                    status: pipeline.status
                    jobs: []
                ])
            else
                @onJobs(project, jobs.sort((a, b) -> a.id - b.id).reduce(
                    (stages, job) ->
                        stage = stages.find(
                            (stage) -> stage.name is job.stage
                        )
                        if not stage?
                            stage =
                                name: job.stage
                                status: 'success'
                                jobs: []
                            stages = stages.concat([stage])
                        stage.jobs = stage.jobs.concat([job])
                        return stages
                , []).map((stage) ->
                    Object.assign(stage, {
                        status: stage.jobs
                            .sort((a, b) -> b.id - a.id)
                            .reduce((status, job) ->
                                switch
                                    when job.status is 'pending' then 'pending'
                                    when job.status is 'created' then 'created'
                                    when job.status is 'canceled' then 'canceled'
                                    when job.status is 'running' then 'running'
                                    when job.status is 'skipped' then 'skipped'
                                    when job.status is 'failed' and
                                        status is 'success' then 'failed'
                                    else status
                            , 'success')
                    })
                ))
        ).catch((error) =>
            console.error "cannot fetch jobs for pipeline ##{pipeline.id} of project #{project.path_with_namespace}", error
            @endUpdate(project)
        )

    onJobs: (project, stages) ->
        @jobs[project.path_with_namespace] = stages.slice()
        @endUpdate(project.path_with_namespace)
        Promise.resolve(stages)

    stop: ->
        if @timeout?
            clearTimeout @timeout
        if @watchTimeout?
            clearTimeout @watchTimeout
        @view.hide()

    deactivate: ->
        @stop()

module.exports = GitlabStatus
