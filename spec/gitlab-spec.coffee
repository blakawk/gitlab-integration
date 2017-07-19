GitLab = require '../lib/gitlab'
nock = require 'nock'

describe "GitLab API", ->
    gitlab =
    project =
        id: 666
        path_with_namespace: 'dummy/project'
    pipeline = { id: 2, name: 'pipeline-2', status: 'failure' }
    pipelines = [
        pipeline,
        { id: 1, name: 'pipeline-1', status: 'success' },
    ]
    jobs = [
        { id: 1, name: 'job-1', stage: 'stage-1', status: 'success' },
        { id: 2, name: 'job-2', stage: 'stage-1', status: 'success' },
        { id: 3, name: 'job-3', stage: 'stage-2', status: 'failure' },
        { id: 4, name: 'job-4', stage: 'stage-2', status: 'success' },
        { id: 5, name: 'job-5', stage: 'stage-3', status: 'failure' },
        { id: 6, name: 'job-6', stage: 'stage-3', status: 'skipped' },
        { id: 7, name: 'job-7', stage: 'stage-4', status: 'failure' },
        { id: 8, name: 'job-8', stage: 'stage-4', status: 'running' },
        { id: 9, name: 'job-9', stage: 'stage-4', status: 'success' },
        { id: 10, name: 'job-10', stage: 'stage-5', status: 'failure' },
        { id: 11, name: 'job-11', stage: 'stage-5', status: 'pending' },
        { id: 12, name: 'job-12', stage: 'stage-5', status: 'success' },
        { id: 13, name: 'job-13', stage: 'stage-5', status: 'failure' },
    ]
    stages = [
        { name: 'stage-1', status: 'success', jobs: jobs.slice(0, 2).reverse() },
        { name: 'stage-2', status: 'failure', jobs: jobs.slice(2, 4).reverse() },
        { name: 'stage-3', status: 'skipped', jobs: jobs.slice(4, 6).reverse() },
        { name: 'stage-4', status: 'running', jobs: jobs.slice(6, 9).reverse() },
        { name: 'stage-5', status: 'pending', jobs: jobs.slice(9, 13).reverse() },
    ]
    beforeEach ->
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

    it "handle jobs with stages", ->
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
