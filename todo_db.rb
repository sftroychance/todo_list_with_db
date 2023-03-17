require "sinatra"
require "tilt/erubis"
require "sinatra/content_for"

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

helpers do
  def all_completed?(list)
    todos_count(list) > 0 && todos_remaining(list) == 0
  end

  def list_class(list)
    "complete" if all_completed?(list)
  end

  def todos_remaining(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].count
  end

  def sort_lists(lists)
    lists.sort_by { |list| all_completed?(list) ? 1 : 0 }
  end

  def sort_todos(list)
    list.sort_by { |todo| todo[:completed] ? 1 : 0 }
  end
end

def load_list(list_id)
  list = @storage.find_list(list_id)

  return list if list

  session[:error] = 'The specified list was not found'
  redirect '/lists'
end

def todo_error(todo)
  unless todo.length.between?(1, 100)
    "The todo must be between 1 and 100 characters."
  end
end

def list_name_error(list_name)
  if !list_name.length.between?(1, 100)
    "The list name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == list_name }
    "The list name must be unique."
  end
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

get "/" do
  redirect "/lists"
end

# view list of todo lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# edit new list
get "/lists/new" do
  erb :new_list, layout: :layout
end

# create new list
post "/lists" do
  list_name = params[:list_name].strip

  error = list_name_error(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# view a todo list
get "/lists/:list_id" do |list_id|
  @list_id = list_id.to_i
  @current_list = load_list(@list_id)

  erb :list, layout: :layout
end

# create a new todo item
post "/lists/:list_id/todos" do |list_id|
  @list_id = list_id.to_i
  @current_list = load_list(@list_id)

  todo = params[:todo].strip

  error = todo_error(todo)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_todo(@list_id, todo)
    session[:success] = "The todo has been added."
    redirect "/lists/#{list_id}"
  end
end

# edit list info
get "/lists/:list_id/edit" do |list_id|
  @list_id = list_id.to_i
  @current_list = load_list(@list_id)

  erb :edit_list
end

# update list name
post "/lists/:list_id/edit" do |list_id|
  @list_id = list_id.to_i
  @current_list = load_list(@list_id)

  new_list_name = params[:new_list_name].strip

  error = list_name_error(new_list_name)

  if error
    session[:error] = error
    session[:entered_name] = params[:new_list_name]
    erb :edit_list
  else
    @storage.update_list_name(@list_id, new_list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{list_id}"
  end
end

# delete a list
post "/lists/:list_id/delete" do |list_id|
  list_id = list_id.to_i

  @storage.delete_list(list_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# delete a todo item
post "/lists/:list_id/todos/:todo_id/delete" do |list_id, todo_id|
  list_id = list_id.to_i
  todo_id = todo_id.to_i

  @storage.delete_todo(list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{list_id}"
  end
end

# update todo status
post "/lists/:list_id/todos/:todo_id" do |list_id, todo_id|
  list_id = list_id.to_i
  todo_id = todo_id.to_i

  is_completed = params[:completed] == "true"

  @storage.update_todo_status(list_id, todo_id, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{list_id}"
end

# mark all todo items in a list completed
post "/lists/:list_id/mark_all_todos_completed" do |list_id|
  list_id = list_id.to_i

  @storage.mark_all_todos_completed(list_id)

  session[:success] = "All todos have been marked completed."

  redirect "/lists/#{list_id}"
end
