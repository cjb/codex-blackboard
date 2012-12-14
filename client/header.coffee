# templates, event handlers, and subscriptions for the site-wide
# header bar, including the login modals.

Handlebars.registerHelper 'link', (args) ->
  args = if typeof(args) is 'string' then {id:args} else args.hash
  n = Names.findOne(args.id)
  return args.id unless n
  extraclasses = if args.class then (' '+args.class) else ''
  title = if args.title then " title='#{args.title}'" else ''
  link = "<a href='/#{n.type}/#{n._id}' class='#{n.type}-link#{extraclasses}' #{title}>"
  link += Handlebars._escape(n.name)
  link += '</a>'
  return new Handlebars.SafeString(link)

$('a.puzzles-link, a.rounds-link, a.chat-link').live 'click', (event) ->
  return unless event.button is 0 # check right-click
  event.preventDefault()
  Router.navigate $(this).attr('href'), {trigger:true}
