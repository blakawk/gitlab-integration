GitLab = require '../lib/gitlab'
log = require '../lib/log'
nock = require 'nock'

describe "GitLab API", ->
    gitlab =
    project =
        id: 666
        path_with_namespace: 'dummy/project'
    anotherProject =
        id: 777
        path_with_namespace: 'another/project'
    sensitiveProject =
        id: 888
        path_with_namespace: 'sEnsItIvE/prOjEct'
    pipeline = { id: 2, name: 'pipeline-2', status: 'failure' }
    pipelines = [
        pipeline,
        { id: 1, name: 'pipeline-1', status: 'success' },
    ]
    externalPipeline =
        id: 3
        name: 'external-pipeline'
        status: 'success'
    jobs = [
        { id: 1, name: 'job-1', stage: 'stage-1', status: 'success' },
        { id: 2, name: 'job-2', stage: 'stage-1', status: 'success' },
        { id: 3, name: 'job-3', stage: 'stage-2', status: 'failed' },
        { id: 4, name: 'job-4', stage: 'stage-2', status: 'success' },
        { id: 5, name: 'job-5', stage: 'stage-3', status: 'failed' },
        { id: 6, name: 'job-6', stage: 'stage-3', status: 'skipped' },
        { id: 7, name: 'job-7', stage: 'stage-4', status: 'failed' },
        { id: 8, name: 'job-8', stage: 'stage-4', status: 'running' },
        { id: 9, name: 'job-9', stage: 'stage-4', status: 'success' },
        { id: 10, name: 'job-10', stage: 'stage-5', status: 'failed' },
        { id: 11, name: 'job-11', stage: 'stage-5', status: 'pending' },
        { id: 12, name: 'job-12', stage: 'stage-5', status: 'success' },
        { id: 13, name: 'job-13', stage: 'stage-5', status: 'failed' },
    ]
    stages = [
        { name: 'stage-1', status: 'success', jobs: jobs.slice(0, 2).reverse() },
        { name: 'stage-2', status: 'failed', jobs: jobs.slice(2, 4).reverse() },
        { name: 'stage-3', status: 'skipped', jobs: jobs.slice(4, 6).reverse() },
        { name: 'stage-4', status: 'running', jobs: jobs.slice(6, 9).reverse() },
        { name: 'stage-5', status: 'pending', jobs: jobs.slice(9, 13).reverse() },
    ]
    beforeEach ->
        log.debug = true
        view = jasmine.createSpyObj 'view', [
            'loading', 'unknown', 'onStagesUpdate'
        ]
        gitlab = new GitLab view

    it "correctly watches a project", ->
        scope = nock('https://gitlab-api')
            .get('/api/v4/projects?membership=yes')
            .reply(200, [ project ])

        promise = gitlab.watch('gitlab-api', 'dummy/project')
        expect(gitlab.view.loading).toHaveBeenCalledWith(
            project.path_with_namespace,
            'loading project...',
        )

        waitsForPromise ->
            promise

        runs ->
            expect(scope.isDone()).toBe(true)
            expect(gitlab.projects['dummy/project']).toEqual(
                host: 'gitlab-api'
                project: project
                repos: undefined
            )

    it "ignores case when looking for a project", ->
        scope = nock('https://gitlab-api')
            .get('/api/v4/projects?membership=yes')
            .reply(200, [ sensitiveProject ])
        promise = gitlab.watch('gitlab-api', 'sensitive/project')
        expect(gitlab.view.loading).toHaveBeenCalledWith(
            'sensitive/project',
            'loading project...',
        )

        waitsForPromise ->
            promise

        runs ->
            expect(scope.isDone()).toBe(true)
            expect(gitlab.projects['sensitive/project']).toEqual(
                host: 'gitlab-api'
                project: sensitiveProject
                repos: undefined
            )

    it "processes only the last pipeline", ->
        scope = nock('https://gitlab-api')
            .get('/api/v4/projects/666/pipelines')
            .reply(200, pipelines)

        gitlab.projects =
            'dummy/project':
                host: 'gitlab-api'
                project: project

        spyOn gitlab, 'updateJobs'

        promise = Promise.all(gitlab.updatePipelines())
        expect(gitlab.view.loading).toHaveBeenCalledWith(
            project.path_with_namespace,
            'loading pipelines...',
        )

        waitsForPromise ->
            promise

        runs ->
            expect(scope.isDone()).toBe(true)
            expect(gitlab.updateJobs).toHaveBeenCalledWith(
                'gitlab-api',
                project,
                pipeline,
            )

    it "handles jobs with stages", ->
        scope = nock('https://gitlab-api')
            .get('/api/v4/projects/666/pipelines/2/jobs')
            .reply(200, jobs)

        promise = gitlab.updateJobs('gitlab-api', project, pipeline)
        expect(gitlab.view.loading)
            .toHaveBeenCalledWith(
                project.path_with_namespace,
                'loading jobs...',
            )

        waitsForPromise ->
            promise

        runs ->
            expect(scope.isDone()).toBe(true)
            expect(gitlab.view.onStagesUpdate).toHaveBeenCalledWith(
                {'dummy/project': stages }
            )

    it "correctly handles external jobs", ->
        scope = nock('https://gitlab-api')
            .get('/api/v4/projects/666/pipelines/3/jobs')
            .reply(200, [])

        gitlab.jobs[project.path_with_namespace] = []

        promise = gitlab.updateJobs('gitlab-api', project, externalPipeline)
        expect(gitlab.view.loading).not.toHaveBeenCalled()

        waitsForPromise ->
            promise

        runs ->
            expect(scope.isDone()).toBe(true)
            expect(gitlab.view.onStagesUpdate).toHaveBeenCalledWith(
                {'dummy/project': [{
                    name: 'external-pipeline', status: 'success', jobs: []
                }]}
            )

    it "correctly handles project with no pipelines", ->
        scope = nock('https://gitlab-api')
            .get('/api/v4/projects/666/pipelines')
            .reply(200, [])

        gitlab.projects =
            'dummy/project':
                host: 'gitlab-api'
                project: project

        spyOn gitlab, 'updateJobs'

        promise = Promise.all(gitlab.updatePipelines())
        expect(gitlab.view.loading).toHaveBeenCalledWith(
            project.path_with_namespace,
            'loading pipelines...',
        )

        waitsForPromise ->
            promise

        runs ->
            expect(scope.isDone()).toBe(true)
            expect(gitlab.updateJobs).not.toHaveBeenCalled()
            expect(gitlab.view.onStagesUpdate).toHaveBeenCalledWith(
                {'dummy/project': []},
            )

    it "correctly handles paging", ->
        scope = nock('https://gitlab-api')
            .get('/api/v4/projects?membership=yes')
            .reply(200, [ project ], {
                'X-Total-Pages': 2,
                'X-Next-Page': 2,
                'X-Page': 1,
                'X-Per-Page': 1,
            })
        scopePage2 = nock('https://gitlab-api')
            .get('/api/v4/projects?membership=yes&per_page=1&page=2')
            .reply(200, [ anotherProject ], {
                'X-Page': 2,
                'X-Per-Page': 1,
                'X-Prev-Page': 1,
            })

        promise = gitlab.watch('gitlab-api', 'another/project')
        expect(gitlab.view.loading).toHaveBeenCalledWith(
            anotherProject.path_with_namespace,
            'loading project...',
        )

        waitsForPromise ->
            promise

        runs ->
            expect(scope.isDone()).toBe(true)
            expect(scopePage2.isDone()).toBe(true)
            expect(gitlab.projects['another/project']).toEqual(
                host: 'gitlab-api'
                project: anotherProject
                repos: undefined
            )

    it "correctly requests pipelines for current branch", ->
        projectScope = nock('https://gitlab-api')
            .get('/api/v4/projects?membership=yes')
            .reply(200, [ project ])
        scope = nock('https://gitlab-api')
            .get('/api/v4/projects/666/pipelines?ref=abranch')
            .reply(200, pipelines)

        repos = jasmine.createSpyObj 'repos', [ 'getShortHead' ]
        repos.getShortHead.andReturn('abranch')

        promise = gitlab.watch('gitlab-api', 'dummy/project', repos).then(
            (updateJobs) -> Promise.all(updateJobs)
        )

        expect(gitlab.view.loading).toHaveBeenCalledWith(
            project.path_with_namespace,
            'loading project...',
        )

        waitsForPromise ->
            promise

        runs ->
            expect(projectScope.isDone()).toBe(true)
            expect(gitlab.view.loading).toHaveBeenCalledWith(
                project.path_with_namespace,
                'loading pipelines...',
            )
            expect(scope.isDone()).toBe(true)
            expect(repos.getShortHead).toHaveBeenCalled()
            expect(gitlab.projects['dummy/project']).toEqual(
                host: 'gitlab-api'
                project: project
                repos: repos
            )

    it "correctly react to removed projects", ->
        repos = jasmine.createSpyObj 'repos', ['getShortHead']
        repos.getShortHead.andThrow(new Error('Repository has been destroyed'))
        spyOn gitlab, 'updateJobs'

        gitlab.projects =
            'dummy/project':
                host: 'gitlab-api'
                project: project
                repos: repos

        promise = Promise.all(gitlab.updatePipelines())

        waitsForPromise ->
            promise

        runs ->
            expect(gitlab.updateJobs).not.toHaveBeenCalled()
            expect(gitlab.view.loading).not.toHaveBeenCalled()
            expect(gitlab.view.onStagesUpdate).toHaveBeenCalledWith({})
