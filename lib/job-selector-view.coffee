{$, $$, SelectListView} = require 'atom-space-pen-views'

class JobSelectorView extends SelectListView
  initialize: (jobs, controller, projectPath) ->
    super

    @controller = controller
    @projectPath = projectPath
    @addClass('overlay from-top')

    jobs?.sort (a, b) ->
      return -1 if a.name < b.name
      return 1 if a.name > b.name
      return -1 if a.id < b.id
      return 1 if a.id > b.id
      return 0

    @setItems jobs

    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @focusFilterEditor()
    @getFilterKey = -> 'name'
    # @loadingArea.append $$ @extraContent
    @handleEvents
    # @loadingArea.show()

  extraContent: ->
    @div class: 'input-block-item', =>
      @div class: 'btn-group', =>
        @button outlet: 'sortButton', class: 'btn', 'Sort'
      @div class: 'btn-group', =>
        @button outlet: 'allButton', class: 'btn', 'All'
      @div class: 'btn-group', =>
        @button outlet: 'selectedButton', class: 'btn', 'Selected'


  handleEvents: ->
    @sortButton.on 'click', => @sort()
    @allButton.on 'click', => @all()

  sort: ->
    @setItems @items.sort (a, b) ->
      return -1 if a.name < b.name
      return 1 if a.name > b.name
      return 0

  all: ->
    @cancel()
    @controller.openLogs(@projectPath, @items)

  selected: ->
    @cancel()
    @controller.openLogs(@projectPath, @getSelectedItems)


  viewForItem: (job) ->
    artifactIcon = if job.artifacts_file then "| <span class='icon gitlab-artifact'/>" else ""
    "<li> <span class='icon gitlab-#{job.status}'/> <strong>#{job.name}</strong> (#{job.id}) | ♨︎ #{Math.round(job.duration)}s #{artifactIcon} | <span class='icon icon-clock'/> #{job.finished_at}  | <small>#{job.runner.description}</small> | <img src='#{job.user.avatar_url}' class='gitlab-avatar'/> #{job.user.name} </li>"

  confirmed: (job) =>
    @cancel()
    if job.artifacts_file
      atom.confirm
        message: 'What to open?'
        detailedMessage: "Do you want to open the log or the report or both or all logs of the group #{job.name}?"
        buttons:
          Group: => @controller.openFailedLogsInGroup(@projectPath, @items, job)
          Log: => @controller.openLog(@projectPath, job)
          Report: => @controller.openReport(@projectPath, job)
          Both: =>
            @controller.openLog(@projectPath, job)
            @controller.openReport(@projectPath, job)
    else
      atom.confirm
        message: 'What to open?'
        detailedMessage: "Do you want to open the log or all logs of the group #{job.name}?"
        buttons:
          Group: => @controller.openFailedLogsInGroup(@projectPath, @items, job)
          Log: => @controller.openLog(@projectPath, job)

  cancelled: ->
    @panel.hide()

module.exports = JobSelectorView
