require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
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

  def sorted_lists(lists)
    lists.sort_by { |list| all_completed?(list) ? 1 : 0 }
  end

  def sorted_todos(list)
    list.sort_by { |todo| todo[:completed] ? 1 : 0 }
  end
end

class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id }
  end

  def all_lists
    @session[:lists]
  end

  def add_list(id, list_name)
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(list_idx)
    @session[:lists].delete_if { |list| list[:id] == list_idx }
  end
end

def load_list(list_idx)
  list = @storage.find_list(list_idx)

  return list if list

  session[:error] = 'The specified list was not found'
  redirect '/lists'
end

def todo_error(todo)
  if !todo.length.between?(1, 100)
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

def next_id(list)
  max = list.map { |item| item[:id] }.max || 0
  max + 1
end

before do
  @storage = SessionPersistence.new(session)
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

get "/lists/new" do
  erb :new_list, layout: :layout
end

post "/lists" do
  list_name = params[:list_name].strip

  error = list_name_error(list_name)

  id = next_id(@storage.all_lists)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.add_list(id, list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:list_idx" do |list_idx|
  @list_idx = list_idx.to_i
  @current_list = load_list(@list_idx)

  erb :list, layout: :layout
end

post "/lists/:list_idx/todos" do |list_idx|
  @list_idx = list_idx.to_i
  @current_list = load_list(@list_idx)

  todo = params[:todo].strip

  error = todo_error(todo)

  id = next_id(@current_list[:todos])

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @current_list[:todos] << { id: id, name: todo, completed: false }
    session[:success] = "The todo has been added."
    redirect "/lists/#{list_idx}"
  end
end

get "/lists/:list_idx/edit" do |list_idx|
  @list_idx = list_idx.to_i
  @current_list = load_list(@list_idx)

  erb :edit_list
end

post "/lists/:list_idx/edit" do |list_idx|
  list_idx = list_idx.to_i
  current_list = load_list(list_idx)

  new_list_name = params[:new_list_name].strip

  error = list_name_error(new_list_name)

  if error
    session[:error] = error
    session[:entered_name] = params[:new_list_name]
    redirect "/lists/#{list_idx}/edit"
  else
    current_list[:name] = new_list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{list_idx}"
  end
end

post "/lists/:list_idx/delete" do |list_idx|
  list_idx = list_idx.to_i

  @storage.delete_list(list_idx)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

post "/lists/:list_idx/todos/:todo_idx/delete" do |list_idx, todo_idx|
  list_idx = list_idx.to_i
  current_list = load_list(list_idx)

  todo_idx = todo_idx.to_i

  current_list[:todos].delete_if { |todo| todo[:id] == todo_idx }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{list_idx}"
  end
end

post "/lists/:list_idx/todos/:todo_idx" do |list_idx, todo_idx|
  list_idx = list_idx.to_i
  current_list = load_list(list_idx)

  todo_idx = todo_idx.to_i

  is_completed = params[:completed] == "true"

  current_list[:todos].each do |todo|
    todo[:completed] = is_completed if todo[:id] == todo_idx
  end

  session[:success] = "The todo has been updated."
  redirect "/lists/#{list_idx}"
end

post "/lists/:list_idx/complete_all_todos" do |list_idx|
  list_idx = list_idx.to_i
  current_list = load_list(list_idx)

  current_list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been marked completed."

  redirect "/lists/#{list_idx}"
end
