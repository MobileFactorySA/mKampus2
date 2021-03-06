#               _   __                                
#              | | / /                                
#     _ __ ___ | |/ /  __ _ _ __ ___  _ __  _   _ ___ 
#    | '_ ` _ \|    \ / _` | '_ ` _ \| '_ \| | | / __|
#    | | | | | | |\  \ (_| | | | | | | |_) | |_| \__ \
#    |_| |_| |_\_| \_/\__,_|_| |_| |_| .__/ \__,_|___/
#                                    | |              
#                                    |_|              

################### CONFIGURATION ###################

StackMob.init
  appName: "mkampus2"
  clientSubdomain: "mobilefactorysa"
  apiVersion: 1
  
moment.lang('pl')

################### JAVASCRIPT EXTENSIONS ###################

do (String) ->
  
  String::startsWith or= (str) ->
    @indexOf(str) is 0
  
  templateCache = {}
  
  String::template = () ->
    templateCache[@] or= Handlebars.compile(@)
  
  String::render = (data) ->
    templateData = _.extend _.clone(window.globals), data
    @template()(templateData)
    
  String::toURL = ->
    encodeURIComponent(@)
  
  String::fromURL = ->
    decodeURIComponent(@)

################### HANDLEBARS PARTIALS ###################
  
partial = (sources) ->
  for name, source of sources
    Handlebars.registerPartial name, source

helper = (helpers) ->
  for name, fn of helpers
    Handlebars.registerHelper name, fn

partial navbar: """
<div class="navbar navbar-fixed-top">
  <div class="navbar-inner">
    <div class="container">
      <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
      </a>
      <div class="nav-collapse collapse">
        <ul class="nav">
          {{#links}}
            <li {{#if active}}class="active"{{/if}}>
              <a class="link" href="{{href}}">{{label}}</a>
            </li>
          {{/links}}
        </ul>
        <ul class="nav pull-right">
          {{#if current_user }}
            <li>
              <a href="/">
                <i class="icon-off icon-white"></i>
                Wyloguj ( {{ current_user }} )
              </a>
            </li>
          {{/if}}
        </ul>
      </div>
    </div>
  </div>
</div>
"""

helper if_eq: (context, options) ->
	if context is options.hash.compare
		options.fn(context)
	else
	  options.inverse(context)

helper restaurantNavbar: (context) ->
  "{{> navbar}}".render links: [
    {href: '#', label: 'Restauracja', active: true}
  ]

helper navbar: (context) ->
  "{{> navbar}}".render links: [
    {href: '#/notifications', label: 'Powiadomienia'}
    {href: '#/surveys',       label: 'Ankiety'}
    {href: '#/informations',  label: 'Informacje'}
    {href: '#/map',           label: 'Mapa'}
    {href: '#/restaurants',   label: 'Restauracje'}
    {href: '#/contact',       label: 'Kontakt'}
  ]

partial footer: """
<footer>
  <a href="http://www.mobilefactory.com/pl/mkampus/"><img src="/img/mkampus.png"/></a>
  <img src="/img/logo.png" />
</footer>
"""

helper footer: ->
  "{{> footer}}".render()

helper header: (title, options) ->
  """
  <header>
    <div class="container list-view">
      <div class="row">
        <div class="span4 category">
          <h1>{{title}}</h1>
        </div>
        
        <div class="span8 add-section">
          {{{add_section}}}
        </div>
      </div>
    </div>
  </header>
  """.render {title, add_section: options.fn(@)}

helper items: (id) ->
  """
  <div class="container">
    <section>
    <div class="row" id="{{id}}">
      ...
    </div>
    </section>
  </div>
  """.render {id}
  
helper layout: (options) ->
  """
  {{{navbar}}}
  {{{content}}}
  """.render {content: options.fn(@)}

helper timeHuman: (time) ->
  timestamp = moment(time)
  timestamp.format('LLL')

helper timeAgo: (time) ->
  timestamp = moment(time)
  timestamp.fromNow()

helper timeSwitch: (time) ->
  """
  <span class="hover-switch">
    <span class="hover-on">{{ timeHuman time }}</span>
    <span class="hover-off">{{ timeAgo time }}</span>
  </span>
  """.render {time}

################### BACKBONE EXTENSIONS ###################

class Model extends StackMob.Model
  
  initialize: ->
    @meta =
      waiting: false
    @on 'sync', @ready, @
    @on 'error', @ready, @
    super
  
  wait: ->
    @meta.waiting = true
    @trigger 'wait'
  
  ready: ->
    @meta.waiting = false
    @trigger 'ready'
  
  isWaiting: ->
    @meta.waiting
  
  save: ->
    super
    @wait()

class Image extends Model
  schemaName: 'image'

class ModelWithImage extends Model

  initialize: ->
    super
    @on 'sync', @updateImageModel
  
  # rollbackImage: ->
  #   @set image_url: @get('image_content')
    
  getImageId: ->
    "#{@constructor.name}_#{@id}"

  updateImageModel: =>
    image = new Image
      image_id: @get('image')
      width: @get('image_width')
      height: @get('image_height')
      url: @get('image_url')
    image.save {}, error: ->
      image.create()
    if @id and not @get('image')
      @fallbackToDefaultImage()
      @save()
  
  defaultImage: -> 
  
  getImageURL: ->
    if img = @get('image_url')
      imageData = img.split("\n")
      if imageData.length is 5
        type = imageData[0].split(" ")[1]
        content = imageData[4]
        "data:#{type};base64,#{content}"
      else
        img
    else
      @defaultImage()
  
  templateData: ->
    _.extend @toJSON(),
      { image_url: @getImageURL() }

  save: ->
    @beforeSave()
    super

  beforeSave: =>
    unless @has('image_url')
      @set({image_url: ""})
    @preventImageDestruction()
    @fallbackToDefaultImage()

  preventImageDestruction: =>
    content = @get('image_content')
    url = @get('image_url')
    if content and content isnt url
      @set image_url: content

  fallbackToDefaultImage: =>
    if @id and not @has('image')
      @set image: @getImageId()

class Collection extends StackMob.Collection

class Group extends Model

  getElements: ->
    unless @fetchElementsPromise?
      @fetchElementsPromise = $.Deferred()
      @informations = new @collectionClass()
      if @id?
        fetchMyElements = new StackMob.Collection.Query()
        # console.log '@id', @id
        fetchMyElements.equals(@schemaName, @id)
        fetchMyElements.notEquals('is_deleted', true)
        @informations.query(fetchMyElements)
        # console.log 'waiting for reset', @informations
        # @informations.on 'all', (event) =>
          # console.log 'informations event', event
        @informations.on 'reset', =>
          # console.log 'reset', @informations
          @fetchElementsPromise.resolve(@informations)
      else
        @fetchElementsPromise.resolve(@informations)
    @fetchElementsPromise

class LoadableCollection extends Collection
  
  isDeletable: true
  
  load: =>
    unless @fetchPromise?
      @fetchPromise = $.Deferred()
      fetchMyElements = new StackMob.Collection.Query()
      fetchMyElements.notEquals('is_deleted', true) if @isDeletable
      @query fetchMyElements
      @on 'reset', =>
        @fetchPromise.resolve(@)
    @fetchPromise

class SortableCollection extends LoadableCollection
  
  comparator: (model) ->
    model.get('position')

  parse: (response) ->
    _(response).reject (model) -> model.is_deleted

  newPosition: ->
    if @length > 0
      sorted = _(@pluck('position').sort((a, b) -> a - b))
      last = if sorted.last() > @length then sorted.last() else @length
      last + 1
    else
      1

  createNew: ->
    new @model({position: @newPosition()})

class View extends Backbone.View
  
  getImagePreview: -> @$('.image-preview')
  
  onImageChange: (e) ->
    
    e.stopPropagation()
    e.preventDefault()
    file = e.target.files[0]
    reader = new FileReader()
    reader.onload = (e) =>
      $image = @getImagePreview()
      $image.attr('src', e.target.result)
      setTimeout =>
        width = $image[0].clientWidth
        height = $image[0].clientHeight
        @model.set {image_width: width, image_height: height}
        base64Content = e.target.result.substring(e.target.result.indexOf(',') + 1, e.target.result.length)
        fileName = file.name
        fileType = file.type
        @model.setBinaryFile('image_url', fileName, fileType, base64Content)
        @model.setBinaryFile('image_content', fileName, fileType, base64Content)
      , 1000
    fileContent = reader.readAsDataURL(file)
  
class CollectionView extends View
  
  waitForCollection: ->
    if @$collection
      @$collection.html """<section class="item loading"><img src="/img/progress.gif"/></section>"""
  
  initialize: ->
    super
    @waitForCollection()
    
    @itemView or= @options.itemView
    $.when(@collection).then (collection) =>
      collection.on 'reset', @addAll
      collection.on 'add', @addAll
      collection.on 'remove', @addAll

  addAll: =>
    $collection = @$collection or @$el
    $.when(@collection).then (collection) =>
      $collection.empty()
      collection.each @addOne

  addOne: (model) =>
    options = _.extend(_.clone(@options), {model, @collection})
    view = new @itemView options
    if @$collection?
      @$collection.append view.render().el
      # if @options.prepend?
      #   @$collection.prepend view.render().el
      # else
      #   # console.log '@$collection', @$collection 
      #   @$collection.append view.render().el

  render: ->
    @$collection or= @$el
    @waitForCollection()
    @addAll()
    @

class AddView extends Backbone.View

  template: """
    <input type="text" class="add" placeholder="{{ placeholder }}"/>
    """

  events:
    'click input': 'add'

  add: (event) ->
    @collection.trigger 'new'
    @trigger 'click'

  getPlaceholder: ->
    @options.placeholder or "Dodaj"

  render: ->
    @$el.html @template.render {placeholder: @getPlaceholder()}
    @

class MenuLayout extends Backbone.View
  
  template: """
    {{#layout}}
      <header>
        <div class="container list-view">
          <div class="row">
            <div class="span4 category">
              <h1>{{ title }}</h1>
            </div>
            <div class="span8 add-section">
            </div>
          </div>
        </div>
      </header>
      <div class="container">
        <section>
          <div class="row menu">
            <div class="progress"><img src="/img/progress.gif"></img></div>
          </div>
        </section>
      </div>
    {{/layout}}
    """
  
  render: ->
    collection = @collection
    title = @title or @options.title
    addView = @addView or @options.addView
    listView = @listView or @options.listView
    
    @$el.html @template.render {title}
    
    $addSection = @$('.add-section')
    $list = @$('.menu')
    
    
    addView.setElement $addSection
    listView.setElement $list
    
    addView.render()
    listView.render()
    @

class SidebarLayout extends Backbone.View
  template: """
    {{#layout}}
      <div class="container item-view">
        <div class="row">
          <div class="span4">
            <div class="category">
              <a href="{{ backLink }}"><h1>{{ title }}</h1></a>
            </div>
            <div class="row hidden-phone menu">
            </div>
          </div>
          <div class="span8 main">
          </div>
        </div>
      </div>
    {{/layout}}
  """
  
  render: ->
    title = @title or @options.title
    backLink = @backLink or @options.backLink
    mainView = @mainView or @options.mainView
    listView = @listView or @options.listView
    
    @$el.html @template.render {title, backLink}
    
    $main = @$('.main')
    $menu = @$('.menu')
    
    mainView.setElement $main
    mainView.render()
    listView.setElement $menu
    listView.render()
    
    @

class SelectableView extends View

  labelAttribute: 'name'
  placeholderLabel: 'Nowy element'
  
  className: 'selectable sortable span4'
  
  attributes: ->
    'data-id': @model.id
    'data-sortable-id': @model.id
  
  template: -> """
    <div>
    <!-- <div class="selectable sortable span4" data-id="{{ id }}" data-sortable-id= "{{ id }}"> -->
    <!-- <div class="{{#if isWaiting}} waiting {{/if}}"> -->
      <p class="date">{{{ timeSwitch createddate }}}</p>
      <p class="content">
        {{#if #{@labelAttribute} }} {{ #{@labelAttribute} }} {{else}} #{@placeholderLabel} {{/if}}
      </p>
    <!-- </div> -->
    </div>
    """

  initialize: ->
    super
    @$el.data('id', @model.id)
    @$el.data('sortable-id', @model.id)
    
    @model.on 'change', @render
    @model.on 'reset', @render
    @model.on 'sync', @render

  events:
    'click': 'triggerSelect'

  triggerSelect: =>
    @model?.trigger 'select', @model
    @trigger 'select', @model
  
  getID: ->
    @model.id
  
  render: =>
    @$el.html @template().render _.extend(@model.toJSON(), {id: @getID(), isWaiting: @model.isWaiting()})    
    @$el.toggleClass('waiting', @model.isWaiting())
    window.app.updateLinks()
    @    


################### LOGIN ########################

class User extends StackMob.User

class Users extends Collection
  model: User

class LoginView extends Backbone.View

  template: """<div class="container" id="login">
      <form action="POST" class="form-horizontal login-form">
      <div class="modal login-modal" style="position: relative; top: auto; left: auto; margin: 0 auto; z-index: 1; max-width: 100%;">
        <div class="modal-header">
          <h3>Uniwersytet Ekonomiczny we Wrocławiu</h3>
        </div>
        <div class="modal-body">
            <fieldset>

              <div class="control-group">
                <label for="login-input" class="control-label">Login</label>
                <div class="controls"><input type="text" id="login-input" class="input-xlarge" autofocus /></div>
              </div>
              <div class="control-group">
                <label for="password-input" class="control-label">Hasło</label>
                <div class="controls"><input type="password" id="password-input" class="input-xlarge" /></div>
              </div>
            </fieldset>

        </div>
        <div class="modal-footer">
          <input id="login-button" type="submit" class="btn btn-big btn-primary" value="Zaloguj" />
        </div>
      </div>
      </form>
      {{{ footer }}}
    </div>"""

  events:
    submit: 'submit'

  submit: (e) =>
    e.preventDefault()
    $('#login-button').button('toggle')
    user = new User({username: @$('#login-input').val(), password: @$('#password-input').val()})
    user.login false,
      success: (u) =>
        @trigger 'login', user
      error: (u, e) =>
        @$('.control-group').addClass('error')
        $('#login-button').button('toggle')

  render: ->
    @$el.html @template.render()
    @$('#login-input').focus()
    @

################### NOTIFICATIONS ###################

class Notification extends Model
  schemaName: 'notification'
  
  @maxLength: 200
  
  @maxDisplayLength: 100
  

class Notifications extends LoadableCollection
  model: Notification
  
  isDeletable: false
  
  comparator: (model) ->
    -model.get('createddate')

class NotificationView extends Backbone.View
  className: 'notification span4'
  template: """
    <p class="date">{{{ timeSwitch createddate }}}</p>
    <p class="content">{{ content }}</p>
    """
    
  render: ->
    @$el.html @template.render @model.toJSON()
    @

class NotificationsView extends CollectionView
  
  itemView: NotificationView
  
  template: """
    {{#layout}}
      {{#header "Powiadomienia"}}
        <form action="" id="new-notification-form" class="editable">
          <textarea name="" id="new-notification-input" rows="1" class="add" placeholder="Treść nowego powiadomienia"></textarea>
          <div class="form-actions edit">
            <div class="row-fluid">
              <div class="span6">
                <div class="progress" id="new-notification-progress">
                  <div id="new-notification-bar" class="bar" style="width: 0%;"></div>
                </div>
              </div>
              <div class="span6">
                <button type="submit" id="new-notification-submit" data-loading-text="Wysyłam..." class="btn btn-primary btn-large pull-right">
                  <i class="icon-ok icon-white"></i>
                  Wyślij
                </button>
                <!-- <input type="submit" id="new-notification-submit" data-loading-text="Wysyłam..." class="btn btn-primary btn-large pull-right" value="Wyślij" /> -->
              </div>
            </div>
          </div>
        </form>
      {{/header}}
      {{{items "notifications"}}}
    {{/layout}}
    """
  
  events:
    'focus #new-notification-input': 'edit'
    'blur #new-notification-input': 'show'
    'keyup #new-notification-input': 'update'
    'submit #new-notification-form': 'submit'
  
  initialize: ->
    @options.prepend = true
    super
  
  edit: ->
    @$editable.addClass('active')
    @$input.attr('rows', 4)
      
  show: ->
    return if @$input.val().length > 0
    @$editable.removeClass('active')
    @$input.attr('rows', 1)
    
  update: ->
    max = Notification.maxLength
    letters = @$input.val().length
    percent = letters / max * 100
    barClass = if letters <= Notification.maxDisplayLength
      'progress-success'
    else if percent <= 100
      'progress-warning'
    else
      'progress-danger'
    @$submit.toggleClass('disabled', percent > 100 or letters == 0)
    if percent > 100
      percent = 100
    @$bar.attr('style', "width: #{percent}%;")
    @$progress.attr('class', "progress #{barClass}")
  
  reset: =>
    @$input.val('')
    @update()
    @$submit.button('reset')
    @show()
  
  submit: (e) ->
    e.preventDefault()
    content = @$input.val()
    return if content.length < 0 or content.length > Notification.maxLength
    @$submit.button('loading')
    StackMob.customcode 'broadcast'
      , {content}
      , success: =>
        $.when(@collection).then (collection) =>
          console.log 'collection', collection
          collection.create {content}, wait: true
          , success: =>
            @reset()
          , failure: =>
            alert('Powiadomienie wysłano, ale nastąpił problem z bazą danych w wyniku czego nie pojawi się na liście. Przepraszamy.')
            @reset()
      , error: =>
        alert('Błąd podczas wysyłania powiadomienia. Spróbuj ponownie później.')
        @$submit.button('reset') 
  
  render: ->
    @$el.html @template.render()
    @$input = @$('#new-notification-input')
    @$progress = @$('#new-notification-progress')
    @$bar = @$('#new-notification-bar')
    @$submit = @$('#new-notification-submit')
    @$editable = @$('.editable')
    @$collection = @$('#notifications')
    super
    @update()
    @

############################# SURVEYS #############################

class Survey extends Model
  schemaName: 'survey'
  
  defaults: ->
    title: ''
  
  validate: ({title}) ->
    if title.length < 1
      return "Ankieta musi mieć tytuł"
    null
  
  initialize: ->
    super
    @on 'sync', @saveQuestions
  
  saveQuestions: =>
    @questions.each (model) =>
      console.log 'question to save', model.toJSON(), model
      model.set survey: @id
      model.save()
      
  getQuestions: ->
    unless @fetchQuestionsPromise?
      @fetchQuestionsPromise = $.Deferred()
      @questions = new Questions()
      if @id?
        fetchMyQuestions = new StackMob.Collection.Query()
        fetchMyQuestions.equals('survey', @id)
        @questions.query(fetchMyQuestions)
        @questions.on 'reset', => @fetchQuestionsPromise.resolve(@questions)
      else
        @fetchQuestionsPromise.resolve(@questions)
    @fetchQuestionsPromise
    

class Surveys extends SortableCollection
  model: Survey
  
  isDeletable: false
  
  comparator: (model) ->
    -model.get('createddate')

  
class Answer extends Model
  schemaName: 'answer'


class Answers extends Collection
  model: Answer
  
  toJSON: ->
    null
  
  getContents: ->    
    _(@pluck('content').map((content) ->
      try
        JSON.parse(content)
      catch error
        content
    )).reject (element) -> _(element).isNull()
  
class Question extends Model
  schemaName: 'question'
  
  defaults:
    type: '1'
    content: ''
    answers: ''

  getUserAnswers: ->
    unless @fetchAnswersPromise?
      @fetchAnswersPromise = $.Deferred()
      @questions =  new Answers()
      if @id?
        fetchMyAnswers = new StackMob.Collection.Query()
        fetchMyAnswers.equals('question', @id)
        @questions.query(fetchMyAnswers)
        @questions.on 'reset', => @fetchAnswersPromise.resolve(@questions)
      else
        @fetchAnswersPromise.resolve(@questions)
    @fetchAnswersPromise
  
  getResults: ->
    promise = $.Deferred()
    $.when(@getUserAnswers()).then (userAnswers) =>
      contents = userAnswers.getContents()
      promise.resolve switch @get('type')
        when '1' #rate
          avg = if contents.length is 0
            0
          else
            sum = _(contents).reduce(((memo, element) -> memo + Number(element)-1), 0)
            sum / contents.length
          Math.round(avg*25)
        when '4' #text
          contents
        when '3' # 'checkbox'
          results = {}
          _(@getAnswerNames()).each (name, index) ->
            results[index] = {name, votes: 0}
          _(contents).each (content) ->
            _(content).each (index) ->
              if results[index]
                results[index].votes += 1
          array = _(results).map (element) -> element
          array
          
        when '2' # 'radio'
          results = {}
          
          _(@getAnswerNames()).each (name, index) ->
            results[index] = {name, votes: 0}
          
          _(contents).each (index) ->
            if results[index]
              results[index].votes += 1
          array = _(results).map (element) -> element
          array
        else
          null
    promise
  
  getAnswerNames: ->
    try
      JSON.parse(@get('answers'))
    catch error
      try
        @get('answers')[1...-1].split(',')
      catch error
        []
  
  setAnswerNames: (answersArray) ->
    @set answers: try
      JSON.stringify(answersArray)
    catch error
      try
        "[" + answersArray.join(",") + "]"
      catch error
        "[]"
      

class Questions extends SortableCollection
  model: Question
  
  types:
    1: 'rate'
    2: 'checkbox'
    3: 'text'
    4: 'radio'
      
class SurveyView extends Backbone.View
  
  template: """
    <div class="survey selectable span4 {{#if active}} active {{/if}}">
      <p class="date">{{{ timeSwitch createddate }}}</p>
      <p class="content">
        {{#if survey_id}}
        {{else}}
          {{#if active}}
            <i class="icon-pencil icon-white"></i>
          {{else}}
            <i class="icon-pencil"></i>
          {{/if}}
        {{/if}}
        {{ title }}
      </p>
    </div>
    """
  
  events:
    'click': 'select'
  
  initialize: ->
    super
    @model.on 'change', @render
    $.when(@collection).then (collection) =>
      collection.on 'show', @onSelect
  
  onSelect: =>
    @render()

  select: ->
    $.when(@collection).then (collection) =>
      collection.trigger 'show', @model
  
  render: =>
    $.when(@collection).then (collection) =>
      active = collection.active and ((@model.id and collection.active.id is @model.id) or (collection.active.cid is @model.cid))
      @$el.html @template.render _.extend(@model.toJSON(), {active})
    @

class QuestionEditView extends Backbone.View
  
  template: """
    <section class="editable {{#if isOpen}} active {{/if}}">
      
      <div class="configurable show">
        <h3>
          <i class="icon-{{icon}}"></i>
          {{ content }}
        </h3>
      </div>
      <div class="row show">
        {{#checkAnswers}}
          <div class="span4 item">
            <label class="checkbox">
              <input type="checkbox" disabled="disabled" />
              {{ this }}
            </label>
          </div>
        {{/checkAnswers}}
        {{#radioAnswers}}
          <div class="span4 item">
            <label class="radio">
              <input type="radio" disabled="disabled" />
              {{ this }}
            </label>
          </div>
        {{/radioAnswers}}
      </div>
      
      <div class="add-section edit">
        <form action="">
          <input class="name add" type="text" autofocus="autofocus" placeholder="Treść nowego pytania" value="{{ content }}"/>
          <div class="form-actions toolbar">
            <div class="btn-group" >
              {{#types}}
                <button class="btn {{#if active}} active {{/if}} type" data-type="{{ type }}">
                  <i class="icon-{{ icon }}"></i>
                  {{ name }}
                </button>
              {{/types}}
            </div>
          </div>
          <textarea rows=3 class="add answers" placeholder="Jedna odpowiedź w jednej linijce">{{ textAnswers }}</textarea>
          <div class="form-actions">
            <button class="btn btn-large destroy-question">
              <i class="icon-remove"></i>
              Usuń pytanie
            </button>
            <button type="submit" class="btn btn-primary btn-large pull-right save">
              <i class="icon-pencil icon-white"></i>
              Zapisz pytanie
            </button>
          </div>
        </form>
      </div>
    </section>
    """
  
  events:
    'click .show': 'edit'
    'click .type': 'setType'
    'click .type > i': 'typeIcon'
    'submit form': 'save'
    'click .destroy-question': 'destroy'
  
  typeIcon: (e) ->
    e.target = $(e.target).parent()[0]
    @setType(e)
  
  initialize: ->
    super
    @isOpen = not @model.get('content')
    @model.collection.on 'edit', @onEdit
    @model.on 'destroy', @onDestroy
  
  onEdit: (model) =>
    if model is @model
      @open()
    else
      @persist()
      if @model.get('content').length > 0
        @save()
      else
        @model.destroy()
  
  onDestroy: =>
    @remove()
  
  destroy: (e) =>
    e.preventDefault()
    @model.collection.trigger 'close'
    @model.destroy() 
  
  save: (event) =>
    event?.preventDefault?()
    @persist()
    if @model.get('content').length > 0
      @close()
      @model.collection.trigger 'close'
    else
      @render()
  
  edit: ->
    @model.collection.trigger 'edit', @model
  
  open: ->
    @isOpen = true
    @render()  
  
  close: (event) ->
    event?.preventDefault?()
    @isOpen = false
    @render()
  
  setType: (e) ->
    e.preventDefault()
    type = $(e.target).data('type')
    return unless type
    type = type.toString()
    @model.set type: type
    @persist()
    @render()
  
  persist: ->
    name = @$('.name').val()
    answers = @serializeAnswers(@$('.answers').val().split("\n"))
    @model.set {content: name, answers}
  
  focus: ->
    @$name.focus()
  
  focusOnAnswers: ->
    @$answers.focus()
  
  icons:
    '1': 'star'
    '2': 'hand-right'
    '3': 'check'
    '4': 'comment'
  
  serializeAnswers: (answersArray) ->
    try
      JSON.stringify(answersArray)
    catch error
      try
        "[" + answersArray.join(",") + "]"
      catch error
        "[]"

  deserializeAnswers: (answersSerialized) ->
    try
      JSON.parse(answersSerialized)
    catch error
      try
        answersSerialized[1...-1].split(',')
      catch error
        []
    
  data: ->
    types = [
        {name: 'Ocena', type: '1', icon: @icons['1']}
        {name: '1 opcja', type: '2', icon: @icons['2']}
        {name: 'Wiele opcji', type: '3', icon: @icons['3']}
        {name: 'Komentarz', type: '4', icon: @icons['4']}
      ]
    type = Number(@model.get('type'))
    types[type - 1].active = true
    
    serializedAnswers = @model.get('answers')
    arrayAnswers = @deserializeAnswers(serializedAnswers)
    textAnswers = arrayAnswers.join("\n")
    
    arrayAnswers = textAnswers.split("\n")
    radioAnswers = if type is 2 then arrayAnswers
    checkAnswers = if type is 3 then arrayAnswers
    
    _.extend @model.toJSON(), {@isOpen, types, textAnswers, checkAnswers, radioAnswers, icon: @icons[type]}
  
  render: ->
    @$el.html @template.render @data()
    @$name = @$('.name')
    @$answers = @$('.answers')
    type = @model.get 'type'
    @$answers.toggleClass 'hidden', type not in ["2", "3"]
    @$('.type').each ->
      $(@).toggleClass 'active', $(@).data('type').toString() == type
    if type in ["2", "3"]
      @focusOnAnswers()
    else
      @focus()
    @

class QuestionView extends Backbone.View
  tagName: 'section'
  
  typeTemplates:
    '1': -> """
      {{#results}}
        <div class="span8 item">
          <div class="row-fluid">
            <div class="span10">
              <div class="progress">
                <div class="bar" style="width: {{ this }}%;"></div>
              </div>
            </div>
            <div class="span2">
              <span class="badge">{{ this }} %</span>
            </div>
          </div>
        </div>
      {{/results}}
      """ # rate
    '2': -> """
      {{#results}}
        <div class="span8 item">
          <label class="radio">
            <input type="radio" disabled="disabled" />
            {{ name }}
            <span class="badge">{{ votes }}</span>
          </label>
        </div>
      {{/results}}
      """ # radio
    '3': -> """
      {{#results}}
        <div class="span8 item">
          <label class="checkbox">
            <input type="checkbox" disabled="disabled" />
            {{ name }}
            <span class="badge">{{ votes }}</span>
          </label>
        </div>
      {{/results}}
      """ # checkbox
    '4': -> """
      {{#results}}
        <div class="span8 item">
          {{ this }}
        </div>
      {{/results}}
      """ # text
  
  template: => """
    <div class="item">
      <h3>
        <i class="icon-{{icon}}"></i>
        {{ content }}
      </h3>
    </div>
    <div class="row">
      #{@typeTemplates[@model.get('type')]()}
    </div>"""
  
  icons:
    '1': 'star'
    '2': 'hand-right'
    '3': 'check'
    '4': 'comment'
  
  serializeAnswers: (answersArray) ->
    try
      JSON.stringify(answersArray)
    catch error
      try
        "[" + answersArray.join(",") + "]"
      catch error
        "[]"

  deserializeAnswers: (answersSerialized) ->
    try
      JSON.parse(answersSerialized)
    catch error
      try
        answersSerialized[1...-1].split(',')
      catch error
        []
  
  data: ->
    types = [
        {name: 'Ocena', type: '1', icon: @icons['1']}
        {name: 'Decyzja', type: '2', icon: @icons['2']}
        {name: 'Wiele opcji', type: '3', icon: @icons['3']}
        {name: 'Komentarz', type: '4', icon: @icons['4']}
      ]
      
    type = Number(@model.get('type'))
    types[type - 1].active = true
    
    serializedAnswers = @model.get('answers')
    arrayAnswers = @deserializeAnswers(serializedAnswers)
    textAnswers = arrayAnswers.join("\n")
    
    radioAnswers = if type is 2 then arrayAnswers
    checkAnswers = if type is 3 then arrayAnswers

    _.extend @model.toJSON(), {types, textAnswers, checkAnswers, radioAnswers, icon: @icons[type]}
  
  render: ->
    @$el.html """<div class="loading"><img src="/img/progress.gif"/></div>"""
    $.when(@model.getResults()).then (results) =>
      data = _.extend(@data(), {results: results})
      @$el.html @template().render data
    @
  

class SurveyShowView extends CollectionView
  
  template: """
    <div id="title-show" class="category">
      <h1 id="title">{{ title }}</h1>
    </div>
    <div id="questions">
    </div>
    """
  
  itemView: QuestionView
  
  initialize: ->
    @collection = @model.getQuestions()
    $.when(@collection).then (collection) ->
      # console.log 'questions of survey', @model, collection
    super
  
  render: ->
    @$el.html @template.render @model.toJSON()
    @$collection = @$('#questions')
    super
    @

class SurveyEditView extends CollectionView
  
  template: """
    <div class="editable" id="title-section">
      <div class="add-section edit">
        <form id="title-edit" action="">
          <input id="title-input" type="text" class="add edit" placeholder="Tytuł nowej ankiety" autofocus="autofocus" value="{{ title }}"/>
          <div class="form-actions">
            <button type="submit" id="title-submit" class="btn btn-primary btn-large pull-right">
              <i class="icon-pencil icon-white"></i>
              Zapisz tytuł
            </button>
          </div>
        </form>
      </div>

      <div id="title-show" class="category show">
        <h1 id="title">{{ title }}</h1>
      </div>
    </div>
    <div id="questions">
    </div>
    <section class="top-level-action-block">
      <div>
        <div class="add-section ">
          <input type="text" class="new-question-button add top-level-actions" placeholder="Treść nowego pytania"/>
        </div>
      </div>
    </section>
    <div class="form-actions section">
      <button class="destroy btn btn-large">
        <i class="icon-remove"></i>
        Usuń ankietę
      </button>
      
      <button id="survey-submit" data-toggle="button" class="btn btn-large btn-primary pull-right top-level-actions">
        <i class="icon-ok icon-white"></i>
        Opublikuj ankietę
      </button>
      
    </div>
    """
  
  itemView: QuestionEditView
  
  initialize: ->
    @surveys = window.app.Surveys
    @collection = @model.getQuestions()
    @model.on 'change:title', @onSetTitle
    @model.on 'sync', @onSync
    $.when(@collection).then (collection) =>
      collection.on 'edit', @onEdit
      collection.on 'close', @onClose  
    super

  events:
    'click .new-question-button': 'createQuestion'
    'submit #title-edit': 'closeTitle'
    'click #title-show': 'openTitle'
    'click .destroy': 'destroy'
    'click #survey-submit': 'publish'
  
  onSetTitle: =>
    collection = window.app.Surveys
    unless collection.include @model
      collection.add @model
  
  onSync: =>
    # $.when(@collection).then (collection) =>
    window.app.Surveys.trigger 'publish', @model
  
  publish: (e) =>
    e?.preventDefault()
    @model.save()
    button = @$('#survey-submit')
    button.addClass('disabled')
  
  destroy: (e) =>
    e.preventDefault()
    @model.destroy()
    $.when(@collection).then (collection) =>
      collection.remove @model
      app.navigate '/surveys', true
    
  createQuestion: =>
    $.when(@collection).then (collection) =>
      position = collection.newPosition()
      console.log 'new position for question', position
      question = new Question({position})
      collection.add question
      collection.trigger 'edit', question
  
  onEdit: (model) =>
    if model is @model
    else
      @closeTitle()
    @$('.top-level-action-block').addClass 'hidden'
    @$('.top-level-actions').attr 'disabled', 'disabled'
  
  onClose: =>
    @$('.top-level-action-block').removeClass 'hidden'
    @$('.top-level-actions').attr 'disabled', false
  
  closeTitle: (e) =>
    e?.preventDefault?()
    previousTitle = @model.get 'title'
    title = @$titleInput.val()
    if title.length is 0
      @openTitle()
    else
      @model.set {title}
      @$title.html title
      @$titleSection.removeClass('active')
      $.when(@collection).then (collection) =>
        collection.trigger 'close'

  openTitle: ->
    @$titleSection.addClass('active')
    @$titleInput.focus()
    $.when(@collection).then (collection) =>
      collection.trigger 'edit', @model
    
  updateState: ->
    title = @model.get('title') 
    unless title
      @openTitle()
  
  render: ->
    @$el.html @template.render @model.toJSON()
    @$collection = @$('#questions')
    @$newQuestionInput = @$('#new-question')
    @$submit = @$('#survey-submit')
    @$titleSection = @$('#title-section')
    @$title = @$('#title')
    @$titleInput = @$('#title-input')
    @$titleEdit = @$('#title-edit')
    @$titleShow = @$('#title-show')
    @$titleSubmit = @$('#title-submit')
    @updateState()
    super
    @

################### INFORMATIONS ########################

class InformationElement extends ModelWithImage
  schemaName: 'information_element'
  
  initialize: ->
    @isOpen = not @id
    super
  
  defaults:
    type: 'text'
  
  parse: (data) ->
    if typeof data is 'object'
      data
    else
      super

class InformationElements extends SortableCollection
  model: InformationElement

class InformationGroup extends Group
  schemaName: 'information_group'
  collectionClass: InformationElements

class InformationGroups extends SortableCollection
  model: InformationGroup
  
class InformationGroupView extends SelectableView

class ElementView extends View
  
  events: ->
    'click .show': 'open'
    'click .save-button': 'save'
    'submit': 'save'
    'click .destroy-button': 'destroy'
    'click .up-button': 'up'
    'click .down-button': 'down'
  
  up: (event) ->
    event.preventDefault()
    sortedAbove = _(@model.collection.filter((model) => model.get('position') < @model.get('position'))).sortBy((m) -> m.get('position'))
    if sortedAbove.length > 0
      swapWith = _(sortedAbove).last()
      myPosition = @model.get('position')
      @model.set position: swapWith.get('position')
      swapWith.set position: myPosition
      @model.collection.sort()
      @model.save({}, {wait:true})
      swapWith.save({}, {wait:true})
  
  down: (event) ->
    event.preventDefault()
    sortedAbove = _(@model.collection.filter((model) => model.get('position') > @model.get('position'))).sortBy((m) -> m.get('position'))
    if sortedAbove.length > 0
      swapWith = _(sortedAbove).first()
      myPosition = @model.get('position')
      @model.set position: swapWith.get('position')
      swapWith.set position: myPosition
      @model.collection.sort()
      @model.save({}, {wait:true})
      swapWith.save({}, {wait:true})
  
  initialize: ->
    super
    @model.on 'sync', @onSync, @
    @model.on 'change', @render, @
    @model.on 'error', @onError, @
  
  open: ->
    @model.isOpen = true
    @render()
  
  onError: ->
  
  persist: ->
    type = @model.get('type')
    if type is "text"
      @model.set text: @$(".text-input").val()
    else if type is "title"
      @model.set title: @$(".title-input").val()
    @model.save({}, {wait: true})
  
  save: (event) ->
    event.preventDefault()
    @persist()
    @close()
  
  destroy: (event) ->
    event.preventDefault()
    @model.save is_deleted: true
    @close()
  
  onSync: ->
    @close()
    if @model.get('is_deleted') is true
      if collection = @model.collection
        collection.remove @model
        collection.sort()
      @remove()
    else
      @render()
  
  close: ->
    @model.isOpen = false
    @render()
  
  render: ->
    data = if @model.templateData? then @model.templateData() else @model.toJSON()
    @$el.html @template().render _.extend(data, {isOpen: @model.isOpen, hasChanged: @model.isWaiting()})
    @

class InformationElementView extends ElementView
  
  modelId: 'information_element_id'
  
  templateShow:
    text: -> """<p>{{ text }}</p>"""
    title: -> """<h3>{{ title }}</h3>"""
    image: -> """<img src="{{ image_url }}" />"""
  
  templateEdit:
    text: -> """<textarea class="text-input add" type="text" rows="5" autofocus="autofocus" placeholder="Treść nowego akapitu">{{ text }}</textarea>"""
    title: -> """<input class="title-input add" type="text" autofocus="autofocus" placeholder="Treść nowego tytułu" value="{{ title }}" />"""
    image: -> """
      <p><img class="image-preview" src="{{ image_url }}"/></p>
      <p><input type="file" class="image-input" name="image" /></p>
      """
  
  template: -> """
    <section class="editable sortable {{#if isOpen}} active {{/if}} {{#if hasChanged}} waiting {{/if}}" data-sortable-id="{{#{@modelId}}}">
      <div class="configurable show">
        #{if template = @templateShow[@model.get('type')] then template()}
      </div>
      <div class="add-section edit">
        <form class="edit-form" action="">
          #{if template = @templateEdit[@model.get('type')] then template()}
          <div class="form-actions">
            <div class="btn-toolbar pull-right">

              <!--<div class="btn-group">
                
                <button class="up-button btn btn-large">
                  <i class="icon-arrow-up"></i>
                </button>
                <button class="down-button btn btn-large">
                  <i class="icon-arrow-down"></i>
                </button>
                
              </div>-->

              <div class="btn-group">
                <button type="submit" class="save-button btn btn-primary btn-large">
                  <i class="icon-pencil icon-white"></i>
                  Zapisz element
                </button>
              </div>
            </div>

            <button class="destroy-button btn btn-large">
              <i class="icon-remove"></i>
              Usuń element
            </button>

          </div>
        </form>
      </div>
    </section>"""
  
  initialize: ->
    super
  
  onError: (model, error) =>
    unless @model.meta.errorOccured
      @model.meta.errorOccured = true
      if @model.get('type') is 'image'
        alert 'Nie udało się wysłać tego obrazka'
        if not @model.id
          @model.collection?.remove @model
          @remove()
          @model.meta.errorOccured = false
        else
          @model.fetch success: =>
            @close()
            @model.meta.errorOccured = false
        
  
  events: ->
    _.extend super,
      {'change .image-input': 'onImageChange'}
    
  open: ->
    super

class SortableCollectionView extends CollectionView
  
  className: 'sortable-ui'
  
  events: ->
    {'sortstop': 'sort'}
  
  afterSort: (collection) ->
    collection.sort()
    
  sort: (event) =>
    $.when(@collection).then (collection) =>      
      @$('.sortable').each (index, element) =>
        # console.log '.sortable', element
        id = $(element).data('sortable-id')
        if model = collection.get(id)
          unless model.get('position') is index
            model.set({position: index})
            model.save()
      @afterSort collection
  
  render: ->
    super
    @$collection.sortable({})
    @$collection.disableSelection()
    @

class MenuCollectionView extends SortableCollectionView
  afterSort: (collection) ->
    collection.sort()

class GroupShowView extends SortableCollectionView
  
  titlePlaceholder: 'Tytuł nowego działu'
  labelAttribute: 'name'
  itemView: InformationElementView
  
  initialize: ->
    @collection = @model.getElements()
    super
  
  actionsButtonGroupTemplate: -> ""
  
  events: ->
    _.extend super,
    { 'click #information-submit': 'save'
    , 'click .destroy': 'destroy'
    }
  
  persist: ->
    @model.set name: @$('#title-input').val()

  save: ->
    @persist()
    @model.save()

  destroy: ->
    @model.save({is_deleted: true})
    @model.collection.sort()
    @model.collection?.remove @model
    app.navigate @navigateToAfterDelete, true
  
  template: -> """
    <div class="editable active" id="title-section">
      <div class="add-section edit">
        <form id="title-edit" action="">
          <input id="title-input" type="text" class="input-title add edit" placeholder="#{@titlePlaceholder}" autofocus="autofocus" value="{{ #{@labelAttribute} }}"/>
        </form>
      </div>

      <div id="title-show" class="category show">
        <h1 id="title">{{#if #{@labelAttribute} }}{{ #{@labelAttribute} }}{{else}}Nowa kategoria{{/if}}</h1>
      </div>
    </div>

    <div id="elements"></div>

    <div class="form-actions section">

      <div class="btn-toolbar pull-right">

        #{@actionsButtonGroupTemplate()}

        <div class="btn-group">
          <button id="information-submit" class="btn btn-large btn-primary top-level-actions">
            <i class="icon-ok icon-white"></i>
            Zapisz
          </button>
        </div>
      </div>

      <button class="destroy btn btn-large">
        <i class="icon-remove"></i>
        Usuń
      </button>
    </div>
    """

  render: ->
    @$el.html @template().render @model.toJSON()
    @$collection = @$('#elements')
    @$("[rel='tooltip']").tooltip({animation: false})
    super


class InformationGroupShowView extends GroupShowView
  
  navigateToAfterDelete: 'informations'
  
  events: ->
    _.extend super,
      'click .create-text': @createElement('text')
      'click .create-title': @createElement('title')
      'click .create-image': @createElement('image')
  
  createElement: (type) -> (event) =>
    event.preventDefault()
    $.when(@model.getElements()).then (informations) =>
      informations.add({type, position: informations.newPosition(), information_group: @model.id})

  actionsButtonGroupTemplate: -> """
    <div class="btn-group">
      
      <button class="create-title btn btn-large" rel="tooltip" title="Dodaj tytuł">
        <i class="icon-bookmark"></i>
      </button>
      
      <button class="create-text btn btn-large" rel="tooltip" title="Dodaj tekst">
        <i class="icon-align-left"></i>
      </button>
      
      <button class="create-image btn btn-large" rel="tooltip" title="Dodaj obrazek">
        <i class="icon-picture"></i>
      </button>
      
    </div>
    """
     
################### CONTACTS ########################

class ContactElement extends Model
  schemaName: 'contact_element'

  parse: (data) ->
    if typeof data is 'object'
      data
    else
      super
  
  @types: [
      {name: 'header', id: "200", icon: 'bookmark', add: 'nagłówek'}
    , {name: 'person', id: "100", icon: 'user', add: 'osobę'}
    , {name: 'phone', id: "1", icon: 'headphones', add: 'telefon'}
    , {name: 'email', id: "2", icon: 'envelope', add: 'email'}
    , {name: 'url', id: "3", icon: 'globe', add: 'stronę www'}
    , {name: 'address', id: "4", icon: 'home', add: 'adres'}
    , {name: 'text', id: "5", icon: 'pencil', add: 'własną etykietę'}
    ]
  
  setDefaultKey: ->
    unless @has 'key'
      @set key: switch @get('type')
        when "1" then 'telefon'
        when "2" then 'email'
        when "3" then 'www'
        when "4" then 'adres'
        when "5" then 'etykieta'
        else undefined
  
  initialize: ->
    @isOpen = not @id
    @setDefaultKey()
    super

class ContactElements extends InformationElements
  model: ContactElement

class ContactGroup extends Group
  schemaName: 'contact_group'
  collectionClass: ContactElements

class ContactGroups extends SortableCollection
  model: ContactGroup

class ContactGroupView extends InformationGroupView

class ContactElementView extends InformationElementView
  
  modelId: 'contact_element_id'
  
  types: 
    "200": 'header1'
    "100": 'person'
    "5": 'text'
    "4": 'address'
    "3": 'url'
    "2": 'email'
    "1": 'phone'
  
  templateShow:
    "200": -> """<h3>{{ value }}"""
    "100": -> """<h4><i class="icon-user"></i> {{ value }}</h4>"""
    "5": -> """<p><span class="info-label"><i class="icon-pencil"></i> {{ key }}</span> {{ value }}</p>"""
    "4": -> """<p><span class="info-label"><i class="icon-home"></i> {{ key }}</span> {{ value }}</p>"""
    "3": -> """<p><span class="info-label"><i class="icon-globe"></i> {{ key }}</span> <a href="http://{{ value }}">{{ value }}</a></p>"""
    "2": -> """<p><span class="info-label"><i class="icon-envelope"></i> {{ key }}</span> <a href="mailto:{{ value }}">{{ value }}</a></p>"""
    "1": -> """<p><span class="info-label"><i class="icon-headphones"></i> {{ key }}</span> {{ value }}</p>"""
  
  templateEditWithKey = (placeholder) -> -> """
    <div class="row-fluid">
      <div class="span2">
        <input class="key add" type="text" placeholder="#{placeholder}" value="{{ key }}"/>
      </div>
      <div class="span10">
        <input class="value add" type="text" autofocus="autofocus" placeholder="" value="{{ value }}"/>
      </div>
    </div>
    """
  
  templateEditWithoutKey = (placeholder) -> ->
    """<input class="value add" type="text" autofocus="autofocus" placeholder="#{placeholder}" value="{{ value }}"/>"""
  
  templateEdit:
    "1": templateEditWithKey 'telefon'
    "2": templateEditWithKey 'email'
    "3": templateEditWithKey 'www'
    "4": templateEditWithKey 'adres'
    "5": -> """
      <div class="row-fluid">
        <div class="span2">
          <input class="key add" type="text" autofocus="autofocus" placeholder="etykieta" value="{{ key }}"/>
        </div>
        <div class="span10">
          <input class="value add" type="text" placeholder="" value="{{ value }}"/>
        </div>
      </div>
      """
    "100": templateEditWithoutKey 'Nazwa osoby lub jednostki'
    "200": templateEditWithoutKey 'Nazwa działu'
  
  persist: ->
    @model.set key: @$('.key').val(), value: @$('.value').val()
    @model.save()

class ContactGroupShowView extends GroupShowView

  titlePlaceholder: 'Tytuł nowego działu'
  labelAttribute: 'name'
  navigateToAfterDelete: 'contact'  
  itemView: ContactElementView

  creationEvents: ->
    events = {}
    _(ContactElement.types).each (type) =>
      events["click .create-#{type.name}"] = (event) =>
        event.preventDefault()
        $.when(@model.getElements()).then (informations) =>
          newPosition = informations.newPosition()
          informations.add({type: type.id, position: newPosition, contact_group: @model.id})
    events
  
  events: =>
    _.extend super, @creationEvents()

  actionsButtonGroupTemplate: -> """
    <div class="btn-group">
      
      {{#types}}
        <button class="create-{{name}} btn btn-large" rel="tooltip" title="Dodaj {{add}}">
          <i class="icon-{{icon}}"></i>
        </button>
      {{/types}}

      <!--
      <button class="btn btn-large dropdown-toggle" data-toggle="dropdown">
        <div class="caret"></div>
      </button>
      <ul class="dropdown-menu">
        {{#types}}
          <li>
            <a class="create-{{name}}" href="#"><i class="icon-{{icon}}"></i> Dodaj {{add}}</a>
          </li>
        {{/types}}
      </ul>
      -->
      
    </div>
    """.render {types: ContactElement.types}

################### PLACES ###################

class Place extends Model
  schemaName: 'location'

class Places extends LoadableCollection
  model: Place
  
  parse: (response) ->
    _(response).reject (model) -> model.is_deleted

class PlaceView extends SelectableView

class PlaceShowView extends Backbone.View
  
  labelAttribute: 'name'
  titlePlaceholder: 'Nazwa nowego miejsca'
  
  template: -> """
    <div id="title-section">
      <div class="add-section">
        <form id="title-edit" action="">
          <input type="text" class="input-title add edit" placeholder="#{@titlePlaceholder}" autofocus="autofocus" value="{{ #{@labelAttribute} }}"/>
        </form>
      </div>
    </div>
    
    <div id="elements">
    </div>
    
    <section class="item">
      <form action="#" class="form-horizontal">
        <div class="row-fluid">
          <div class="span12">
            <div class="control-group">
              <label for="" class="control-label">Opis</label>
              <div class="controls"><textarea class="span12 input-description">{{ description }}</textarea></div>
            </div>
            <div class="control-group">
              <label for="" class="control-label">Szerokość geograficzna</label>
              <div class="controls"><input type="text" class="span6 input-latitude" value="{{ latitude }}" placeholder="51.110195"/></div>
            </div>
            <div class="control-group">
              <label for="" class="control-label">Długość geograficzna</label>
              <div class="controls"><input type="text" class="span6 input-longitude" value="{{ longitude }}" placeholder="17.031404"/></div>
            </div>
          </div>
        </div>
        
      </form>
    </section>
    
    <div id="elements"></div>
      
    <div class="form-actions section">
      
      <button class="destroy btn btn-large">
        <i class="icon-remove"></i>
        Usuń
      </button>
      
      <button class="save btn btn-large btn-primary pull-right">
        <i class="icon-ok icon-white"></i>
        Zapisz
      </button>
    </div>
    """
  
  events:
    'click .save': 'save'
    'click .destroy': 'destroy'
  
  initialize: ->
    super
    @model.on 'change', @render
    @model.on 'reset', @render
  
  save: (e) =>
    e.preventDefault()
    attributes =
      name: @$('.input-title').val()
      description: @$('.input-description').val()
      latitude: Number(@$('.input-latitude').val())
      longitude: Number(@$('.input-longitude').val())
    @model.set attributes
    @trigger 'save', @model
  
  destroy: (e) =>
    e.preventDefault()
    @model.set is_deleted: true
    @trigger 'destroy', @model
  
  render: =>
    @$el.html @template().render @model.toJSON()
    @

################### RESTAURANTS ###################

class RestaurantUser extends StackMob.User
  
  initialize: ->
    @meta = {waiting: false}
    @on 'sync', => @meta.waiting = false
    @on 'error', => @meta.waiting = false
    @on 'destroy', =>
      if @collection
        @collection.remove @
    super
  
  isWaiting: ->
    @meta.waiting
    false
  
  destroyWithDependencies: (options) ->
    options = _.extend {success: (->), error: (->)}, options
    {success, error} = options
    companionRestaurant = new Restaurant({restaurant_id: @id})
    companionRestaurant.destroyWithDependencies
      success: =>
        @destroy {success, error}
      error: (event, model) =>
        alert 'Nie udało się usunąć restaracji. Próbuj ponownie.'
        error(event, model)

  save: ->
    super
    @meta.waiting = true
  
  defaults:
    role: "restaurant"
  
  validate: (attrs) ->
    return "rola powinna być ustawiona na 'restaurant' a jest #{attrs.role}" if attrs.role isnt "restaurant"
    return "Nazwa new zabroniona" if attrs.username is "new"
    return "Nazwa admin zabroniona" if attrs.username is "admin"

class RestaurantUsers extends LoadableCollection
  model: RestaurantUser
  
  isDeletable: false
  
  parse: (response) ->
    _(response).reject (model) -> model.is_deleted or model.role isnt "restaurant"

class RestaurantUserView extends SelectableView
  labelAttribute: 'username'
  
  getID: ->
    @model.get('username')
  
  initialize: ->
    super
    @model.on 'sync', @render, @
    @model.on 'change', @render, @

class RestaurantUserShowView extends Backbone.View
  labelAttribute: 'username'
  titlePlaceholder: 'Nazwa nowej restauracji'
  
  template: -> """
    <div id="title-section">
      <div class="add-section">
        <input type="text" class="input-title add edit" {{#if #{@labelAttribute} }}disabled{{/if}} placeholder="#{@titlePlaceholder}" autofocus="autofocus" value="{{ #{@labelAttribute} }}"/>
      </div>
    </div>
    
    <section class="item row-fluid">
      <div class="span12 form-horizontal">
        <legend>
          Dedykowany użytkownik
          <small>mogący aktualizować dane teleadresowe i menu</small>
        </legend>
        <div class="control-group">
          <label for="" class="control-label">Identyfikator</label>
          <div class="controls"><input type="text" disabled class="span12 input-username" value="{{ #{@labelAttribute} }}"/></div>
        </div>
        
        <div class="control-group">
          <label for="" class="control-label">Hasło</label>
          <div class="controls"><input type="password" class="span12 input-password"/></div>
        </div>
      
        <div class="control-group">
          <label for="" class="control-label">Hasło ponownie</label>
          <div class="controls"><input type="password" class="span12 input-password-confirmation"/></div>
        </div>
        
      </div>
    </section>
      
    <div class="form-actions section">
      
      <button class="destroy btn btn-large">
        <i class="icon-remove"></i>
        Usuń
      </button>
      
      <button class="save btn btn-large btn-primary pull-right">
        <i class="icon-ok icon-white"></i>
        Zapisz
      </button>
    </div>
    """
  
  events:
    'click .save': 'save'
    'click .destroy': 'destroy'
    'keyup .input-title': 'updateName'

  initialize: ({@user}) ->
    super
    @model.on 'change', @render
    @model.on 'reset', @render
    @model.on 'destroy', @onDestroy, @
  
  onDestroy: ->
    @trigger 'destroy', @model
  
  updateName: (e) =>
    @$('.input-username').val(@$('.input-title').val())  
  
  save: (e) =>
    e.preventDefault()
    
    if @model.isNew()
      username = @$('.input-title').val()
      
      if username is "admin" or username is "new"
        alert("Nazwa #{username} jest zastrzeżona. Wybierz inną.")
        @$('.input-title').focus()
        return
        
      unless username
        alert('Musisz podać nazwę restauracji')
        @$('.input-title').focus()
        return
    else
      username = @model.get('username')
      
    password = @$('.input-password').val()
    unless password
      alert('Musisz podać hasło użytkownika')
      @$('.input-password').focus()
      return
    passwordConfirmation = @$('.input-password-confirmation').val()
    if password isnt passwordConfirmation
      alert('Oba hasła muszą być jednakowe')
      @$('.input-password-confirmation').focus()
      return
    @model.set {username, password}
    @trigger 'save', @model, username, password

  destroy: (e) =>
    e.preventDefault()
    @model.destroyWithDependencies()
  
  render: =>
    @$el.html @template().render @model.toJSON()
    @


################### Admin Router ###################

class App extends Backbone.Router
  
  routes:
    '': 'index'
    'notifications': 'notifications'
    'surveys': 'surveys'
    'surveys/new': 'newSurvey'
    'surveys/:id': 'showSurveyById'
    'informations': 'informations'
    'informations/:id': 'informations'
    'map': 'map'
    'map/:id': 'map'
    'restaurants': 'restaurants'
    'restaurants/:id*': 'restaurants'
    'contact': 'contact'
    'contact/:id': 'contact'
   
  initialize: ->
    super
    @on 'all', @updateLinks
    @$main = $('body')
    
    @Notifications = new Notifications()
    
    @Surveys = new Surveys()
    @Surveys.on 'new', => @navigate '/surveys/new', true
    @Surveys.on 'show', @onSelectSurvey
    @Surveys.on 'publish', (model) =>
      @Surveys.add model
      @navigate "/surveys/#{model.id}", true
    
    @InformationGroups = new InformationGroups()
    @InformationGroups.on 'select', (model) =>
      @navigate "/informations/#{model.id}", true
    
    @ContactGroups = new ContactGroups()
    @ContactGroups.on 'select', (model) =>
      @navigate "/contact/#{model.id}", true
    
    @Places = new Places()
    @Places.on 'select', (model) =>
      @navigate "/map/#{model.id}", true
    
    @RestaurantUsers = new RestaurantUsers()
    @RestaurantUsers.on 'select', (model) =>
      @navigate "/restaurants/#{model.id}", true
  
  onSelectSurvey: (model) =>
    @Surveys.active = model
    @navigate "/surveys/#{model.id or model.cid}"
    @showSurvey(model)
  
  setView: (view) ->
    @$main.html(view.render().el)
    @updateLinks()
  
  notifications: ->
    @setView new NotificationsView({collection: @Notifications.load()})
    @Notifications.fetch()
  
  surveys: ->
    collection = @Surveys
    collection.active = null
    listView = new CollectionView({collection: collection.load(), itemView: SurveyView})
    addView = new AddView({collection, placeholder: 'Tytuł nowej ankiety'})
    view = new MenuLayout({title: 'Ankiety', listView, addView})
    @setView view
  
  newSurvey: ->
    model = new Survey()
    collection = @Surveys
    collection.active = model
    mainView = new SurveyEditView({model})
    listView = new CollectionView({collection, itemView: SurveyView, active: model})
    view = new SidebarLayout({title: 'Ankiety', backLink: '#/surveys', mainView, listView})
    @setView view
    collection.load()
    mainView.openTitle()
    
  showSurvey: (model) => 
    window.model = model 
    collection = @Surveys
    mainView = if model.id? then new SurveyShowView({model}) else new SurveyEditView({model})
    listView = new CollectionView({collection, itemView: SurveyView})
    view = new SidebarLayout({title: 'Ankiety', backLink: '#/surveys', mainView, listView})
    @setView view
  
  showSurveyById: (id) =>
    $.when(@Surveys.load()).then (collection) =>
      model = collection.get(id) or collection.getByCid(id)
      if model?
        @showSurvey model
      else
        @navigate '/surveys', true
  
  informations: (id) =>
    collection = @InformationGroups
    
    listView = new MenuCollectionView({collection: collection.load(), itemView: InformationGroupView})
    
    if id? # pokaż dany element
      if id is 'new'
        $.when(collection.load()).then (collection) =>
          window.model = model = collection.createNew()
          collection.add model
          model.save {}, success: =>
            @navigate "/informations/#{model.id}", true
      else
        $.when(collection.load()).then (collection) =>
          if window.model = model = collection.get(id)
            mainView = new InformationGroupShowView({model})
            view = new SidebarLayout({title: 'Informacje', backLink: '#/informations', mainView, listView})
            @setView view
          else
            console.warn "Nie ma elementu o identyfikatorze #{id}. Przekierowuję do listy elementów."
            @navigate '/informations', true
    else # pokaż listę elementów
      addView = new AddView({collection, placeholder: 'Tytuł nowego działu'})
      addView.on 'click', =>
        @navigate('informations/new', true)
      view = new MenuLayout({title: 'Informacje', listView, addView})
      @setView view
      $.when(collection.load()).then =>
        @updateLinks()
  
  contact: (id) =>
    collection = @ContactGroups

    listView = new MenuCollectionView({collection: collection.load(), itemView: ContactGroupView})

    if id? # pokaż dany element
      if id is 'new'
        $.when(collection.load()).then (collection) =>
          window.model = model = new ContactGroup()
          collection.add model
          model.save {}, success: =>
            @navigate "/contact/#{model.id}", true
      else
        $.when(collection.load()).then (collection) =>
          if window.model = model = collection.get(id)
            mainView = new ContactGroupShowView({model})
            view = new SidebarLayout({title: 'Kontakt', backLink: '#/contact', mainView, listView})
            @setView view
          else
            console.warn "Nie ma elementu o identyfikatorze #{id}. Przekierowuję do listy elementów."
            @navigate '/contact', true
    else # pokaż listę elementów
      addView = new AddView({collection, placeholder: 'Tytuł nowego działu'})
      addView.on 'click', =>
        @navigate('contact/new', true)
      view = new MenuLayout({title: 'Kontakt', listView, addView})
      @setView view
      $.when(collection.load()).then @updateLinks
    
  map: (id) =>
    collection = @Places

    listView = new CollectionView({collection: collection.load(), itemView: PlaceView})
    
    if id is "new" # utwórz nowy element
      model = new Place()
      mainView = new PlaceShowView({model})
      view = new SidebarLayout({title: 'Mapa', backLink: '#/map', mainView, listView})
      @setView view
      mainView.on 'save', (model) =>
        collection.create model
      mainView.on 'destroy', (model) =>
        @navigate "/map", true
      model.on 'sync', =>
        @navigate "/map/#{model.id}", true
    else if id? # pokaż dany element
      $.when(collection.load()).then (collection) =>
        if model = collection.get(id)
          mainView = new PlaceShowView({model})
          mainView.on 'save', (model) =>
            model.save()
          mainView.on 'destroy', (model) =>
            model.save()
            collection.remove(model)
            @navigate "/map", true
          view = new SidebarLayout({title: 'Mapa', backLink: '#/map', mainView, listView})
          @setView view
        else
          console.warn "Nie ma elementu o identyfikatorze #{id}. Przekierowuję do listy elementów."
          @navigate '/map', true
    else # pokaż listę elementów
      addView = new AddView({collection, placeholder: 'Nazwa nowego miejsca'})
      addView.on 'click', => @navigate '/map/new', true
      view = new MenuLayout({title: 'Mapa', listView, addView})
      @setView view
      collection.load()
  
  restaurants: (id) =>
    
    # id = id.fromURL()
    
    collection = @RestaurantUsers
    
    title = "Restauracje"
    
    placeholder = "Nazwa nowej restauracji"
    
    path = "/restaurants"
    
    ShowView = RestaurantUserShowView
    
    MenuItemView = RestaurantUserView
    
    listView = new CollectionView({collection: collection.load(), itemView: MenuItemView})

    if id is "new" # utwórz nowy element
      model = new RestaurantUser({username: undefined})
      mainView = new ShowView({model, collection})
      view = new SidebarLayout({title, backLink: "##{path}", mainView, listView})
      @setView view
      mainView.on 'save', (model) =>
        collection.create model
      mainView.on 'destroy', (model) =>
        @navigate path, true
      model.on 'sync', =>
        @navigate "#{path}/#{model.id.toURL()}", true
            
    else if id? # pokaż dany element
      $.when(collection.load()).then (collection) =>
        if model = collection.get(id)
          mainView = new ShowView({model})
          mainView.on 'save', (model, username, password) =>
            model.destroy success: =>
              collection.create {username, password}, success: =>
                @navigate "#{path}/#{model.id.toURL()}", true
          mainView.on 'destroy', (model) =>
            @navigate path, true
            console.log 'mainView.on destroy', model, @RestaurantUsers
          view = new SidebarLayout({title, backLink: "##{path}", mainView, listView})
          @setView view
        else
          console.warn "Nie ma elementu o identyfikatorze #{id}. Przekierowuję do listy elementów."
          @navigate path, true
    else # pokaż listę elementów
      addView = new AddView({collection, placeholder})
      addView.on 'click', => @navigate "#{path}/new", true
      view = new MenuLayout({title, listView, addView})
      @setView view
    
    collection.load()
  
  index: ->
    @navigate '/notifications', true
    
  updateLinks: =>
    hash = window.location.hash
    unless hash.startsWith('#/')
      hash = '#/' + hash[1..]
    $("a[href].link").each ->
      href = $(@).attr('href')
      active = hash is href or hash.startsWith(href) and hash.charAt(href.length) is '/'
      $(@).parent().toggleClass 'active', active
    
    $("[data-id]").each ->
      parts = hash.split('/')
      id = parts[parts.length-1]
      $el = $(@)
      $el.toggleClass 'active', $el.data('id') is id

############################### Restaurant Router ###############################

class Restaurant extends ModelWithImage
  schemaName: 'restaurant'
  
  destroyMenu: (options) ->
    options or= {}
    options.success or= ->
    options.error or= ->
    {success, error} = options
    
    new MenuItems().getByRestaurantId @id, (e, collection) ->
      if e
        error(e)
      else
        itemsNumber = collection.length
        success() if itemsNumber is 0
        deletedItemsNumber = 0 
        collection.each (model) ->
          model.destroy
            success: ->
              deletedItemsNumber += 1
              if deletedItemsNumber is itemsNumber
                success()
            error: error
  
  destroyWithDependencies: (options) ->
    options or= {}
    options.success or= ->
    options.error or= ->
    {success, error} = options
    
    @destroyMenu
      success: =>    
        @set is_deleted: true
        @save {}
        , success: =>
          success(@)
          @trigger 'destroy'
        , error: error
      error: error

class Restaurants extends LoadableCollection
  model: Restaurant
  
  getById: (id, callback) ->
    q = new Restaurants.Query()
    q.equals('restaurant_id', id)
    @query q
    , success: (collection) =>
      callback(null, collection.first())
    , error: (e) =>
      callback(e)

class MenuItem extends ModelWithImage
  schemaName: 'menu_item'
  
  initialize: ->
    super
    @on 'all', (event) => console.log 'event', event, @

class MenuItems extends Collection
  model: MenuItem
  
  parse: (response) ->
    _(response).reject (model) -> model.is_deleted
  
  comparator: (menuItem) ->
    a = (if menuItem.get('is_featured') then -1000 else 0) + menuItem.get('price')
    a
  
  defaults:
    is_featured: false
  
  getByRestaurantId: (id, callback) ->
    q = new MenuItems.Query()
    q.equals('restaurant', id)
    @query q
    , success: (collection) =>
      callback(null, collection)
    , error: (e) =>
      callback(e)

class RestaurantMenuItemView extends View
  template: -> """
    <section class="menu-item editable">
      <div class="configurable show">
        <div class="row-fluid">
          <div class="span2">
            <img src="{{ image_url }}" width="50px" />
          </div>
          <div class="span10">
            <h3>
              {{#if is_featured}}
                <i class="icon-star"></i>
              {{/if}}
              {{ name }}
              <small>{{ price }} zł</small>
            </h3>
            <p>{{ description }}</p>
          </div>
        </div>
      </div>
      <div class="row-fluid edit">
        <form class="span12 item compact-bottom">
          
          <div class="control-group">
            <label for="" class="control-label"></label>
            <div class="controls">
              <img class="image-preview" src="{{ image_url }}"/>
            </div>
          </div>
        
          <div class="control-group">
            <label for="" class="control-label">Zdjęcie</label>
            <div class="controls">
              <input type="file" class="input-image" name="image" />
            </div>
          </div>
        
          <div class="control-group">
            <label for="" class="control-label">Nazwa</label>
            <div class="controls"><input type="text" class="span12 input-name" value="{{ name }}"/></div>
          </div>
          
          <div class="control-group">
            <label for="" class="control-label">Cena</label>
            <div class="controls"><input type="text" class="span12 input-price" value="{{ price }}" placeholder="9.99"/></div>
          </div>
          
          <div class="control-group">
            <label for="" class="control-label">Opis</label>
            <div class="controls">
              <textarea rows="3" class="span12 input-description">{{ description }}</textarea>
            </div>
          </div>
          
          <div class="control-group">
            <label for="" class="control-label"><i class="icon-star"></i> Polecane</label>
            <div class="controls">
                <input type="checkbox" class="span12 input-featured" {{#if is_featured}}checked{{/if}}/>
            </div>
          </div>
          
          <div class="form-actions compact">
            
            <div class="btn-group pull-right">
              <button class="btn btn-large cancel pull-right">
                <i class="icon-arrow-left"></i>
                Anuluj
              </button>
              <button class="btn btn-primary btn-large save pull-right">
                <i class="icon-ok icon-white"></i>
                Zapisz
              </button>
            </div>
            
            <button class="btn btn-large destroy">
              <i class="icon-remove"></i>
              Usuń
            </button>
            
          </div>
          
        </form>
      </div>
    </section>
  """
  
  initialize: ->
    super
    @model.on 'sync', @onSync, @
    @model.on 'error', @onError, @
    # @model.on 'reset', @render, @
    # @model.on 'all', (event) -> console.log 'event', event
  
  events:
    'click .show': 'edit'
    'click .save': 'save'
    'submit form': 'save'
    'click .destroy': 'destroy'
    'change .input-image': 'onImageChange'
    'click .cancel': 'show'
  
  onSync: (e) ->
    @show()
  
  onError: (e) ->
    alert('Aktualizacja nie powiodła się, spróbuj ponownie później')
    @model.wait()
    @show()
    @model.fetch
      success: =>
        @model.ready()
        @render()
    
  edit: (e) =>
    @model.meta.editMode = true
    @render()
  
  show: (e) =>
    e?.preventDefault()
    @model.meta.editMode = false
    @render()
  
  save: (e) =>
    e.preventDefault()
    e.stopPropagation()
    
    name = @$('.input-name').val()
    desc = @$('.input-description').val()
    price = Number(@$('.input-price').val())
    is_featured = @$('.input-featured').attr('checked')
    
    unless name
      alert("Musisz podać nazwę")
      @$('.input-name').focus()
      return
    
    @model.set
      name: @$('.input-name').val()
      description: @$('.input-description').val()
      price: Number(@$('.input-price').val())
      is_featured: !! @$('.input-featured').attr('checked')
      restaurant: @options.restaurant
    @model.save()
    @$('section').addClass('waiting')
  
  destroy: (e) =>
    e.preventDefault()
    @model.set is_deleted: true
    @model.save()
    @remove()
    @collection.remove @model
  
  render: =>
    @$el.html @template().render @model.templateData()
    @$('section').toggleClass('waiting', @model.meta.waiting)
    if @model.meta.editMode or not @model.get('name')
      @$('section').addClass('active')
    else
      @$('section').removeClass('active')
    @

class RestaurantView extends CollectionView
  
  itemView: RestaurantMenuItemView
  
  getImagePreview: ->
    @$('.restaurant-image-preview')
  
  template: -> """
    {{{ restaurantNavbar }}}
    
    <div class="container">
      
      <div class="row">
        <div class="span6">
            <div class="category">
              <h1>
                {{ name }}
                <small>Informacje o restauracji</small>
              </h1>
            </div>
          <form id="restaurant-info-form">
          
            <section class="row-fluid item restaurant-form-section">
              <div class="span12 form-horizontal">
                
                <div class="control-group">
                  <label for="" class="control-label"></label>
                  <div class="controls">
                    <img class="restaurant-image-preview" src="{{ image_url }}"/>
                  </div>
                </div>
                
                <div class="control-group">
                  <label for="" class="control-label">Zdjęcie</label>
                  <div class="controls">
                    <input type="file" class="restaurant-input-image" name="image" />
                  </div>
                </div>
                
                <div class="control-group">
                  <label for="" class="control-label">Nazwa</label>
                  <div class="controls">
                    <input type="text" disabled class="span12" value="{{ name }}"/>
                  </div>
                </div>

                <div class="control-group">
                  <label for="" class="control-label">Adres</label>
                  <div class="controls">
                    <textarea class="span12 input-address">{{ address }}</textarea>
                  </div>
                </div>
              
                <div class="control-group">
                  <label for="" class="control-label">Telefon</label>
                  <div class="controls">
                    <input type="text" class="span12 input-phone" value="{{ phone }}"/>
                  </div>
                </div>
              
                <div class="control-group">
                  <label for="" class="control-label">Strona www</label>
                  <div class="controls">
                    <input type="text" class="span12 input-url" value="{{ url }}"/>
                  </div>
                </div>
              
              </div>
            </section>
            
            <div class="form-actions section">
              <button class="btn btn-primary btn-large pull-right save">
                <i class="icon-ok icon-white"></i>
                Zapisz
              </button>
            </div>
            
          </form>
        </div>
        <div class="span6">
          <div class="category">
            <h1>
              Menu
            </h1>
          </div>
          
          <div id="menu" class="clearfix">
            <section class="item">
              Brak pozycji menu
            </section>
          </div>          
          <div class="form-actions section">
            <button class="btn btn-primary btn-large pull-right create">
              <i class="icon-plus icon-white"></i>
              Dodaj do menu
            </button>
          </div>
        </div>
      </div>
      <!-- {{{footer}}} -->
    </div>"""
  
  initialize: ->
    @model.on 'reset', @render
    @model.on 'sync', @render
    @model.on 'error', @onError, @
    # window.model = @model
    super
    
  onError: ->
    unless @model.meta.errorOccured is true
      @model.meta.errorOccured = true
      @model.wait()
      @model.fetch
        success: =>
          @model.ready()
          @render()
          @model.meta.errorOccured = false
      alert('Nie udało się wprowadzić tej zmiany. Spróbuj ponownie później.')
    
  events:
    'click .save': 'save'
    'submit #restaurant-info-form': 'save'
    'click .create': 'create'
    'change .restaurant-input-image': 'onImageChange'
  
  save: (e) =>
    @$('.restaurant-form-section').addClass('waiting')    
    e.preventDefault()
    @model.set
      address: @$('.input-address').val()
      phone: @$('.input-phone').val()
      url: @$('.input-url').val()
    @model.save()
  
  create: (e) =>
    e.preventDefault()
    @collection.add new MenuItem
  
  render: =>
    @$el.html @template().render @model.toJSON()
    @$collection = @$('#menu')
    super
  
$ ->
  window.globals = {}
  
  $("[rel='tooltip']").tooltip()
  
  displayRestaurantPanelById = (id, user) ->
    new Restaurants().getById id, (error, model) =>
      if error
        console.error "Nie mogę ściągnąć restauracji o id #{id}", error
      else
        unless model
          model = new Restaurant({restaurant_id: id, name: id})
          model.create()
        new MenuItems().getByRestaurantId id, (e, collection) ->
          if e
            console.error "Nie mogę ściągnąć menu dla restauracji o id #{id}", e
          else
            view = new RestaurantView({model, collection, restaurant: id})
            $('body').html view.render().el
  
  bazylia = off
  auth = on
  
  if bazylia
    window.globals.current_user = "Bazylia"
    displayRestaurantPanelById 'Bazylia', new User({username: "Bazylia", role: "restaurant", restaurant: "Bazylia"})
  else  
    if auth
      loginView = new LoginView()
      $('body').html loginView.render().el
      loginView.on 'login', (user) ->
        window.globals.current_user = user.get('username')
        user.fetch success: =>
          if user.get('role') is "restaurant"
            id = user.id
            displayRestaurantPanelById id, user
          else # admin
            window.app = new App({user})
            Backbone.history?.start()
    else
      window.app = new App()
      Backbone.history?.start()

######################### Prefetching #########################

m1 = new Image()
m1.src = '/img/waiting.png'
m2 = new Image()
m2.src = '/img/progress.gif'
m3 = new Image()
m3.src = '/img/waiting-active.png'

######################### / Prefetching #########################