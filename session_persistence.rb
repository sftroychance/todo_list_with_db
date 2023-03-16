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

  def create_list(list_name)
    id = next_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    @session[:lists].delete_if { |list| list[:id] == list_id }
  end

  def update_list_name(list_id, new_list_name)
    list = find_list(list_id)
    list[:name] = new_list_name
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].delete_if { |todo| todo[:id] == todo_id }
  end

  def create_todo(list_id, todo)
    list = find_list(list_id)
    todo_id = next_id(list[:todos])
    list[:todos] << { id: todo_id, name: todo, completed: false }
  end

  def update_todo_status(list_id, todo_id, updated_status)
    list = find_list(list_id)
    todo = list[:todos].find { |t| t[:id] == todo_id }
    todo[:completed] = updated_status
  end

  def mark_all_todos_completed(list_id)
    list = find_list(list_id)

    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

  private

  def next_id(list)
    max = list.map { |item| item[:id] }.max || 0
    max + 1
  end
end