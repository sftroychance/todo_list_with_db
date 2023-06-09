require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end

    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = <<~SQL
          SELECT l.id, l.name,
              count(*) AS todos_count,
              count(*) FILTER (WHERE t.completed = false) 
                AS todos_remaining_count
            FROM lists l
            LEFT JOIN todos t
            ON l.id = t.list_id
            WHERE l.id = $1
            GROUP BY l.id;
    SQL
    result = query(sql, id)

    tuple_to_list_hash(result.first)
  end

  def all_lists
    sql = <<~SQL
            SELECT l.id, l.name,
              count(t.id) AS todos_count,
              count(t.id) FILTER (WHERE t.completed = false) 
                AS todos_remaining_count
            FROM lists l
            LEFT JOIN todos t
            ON l.id = t.list_id
            GROUP BY l.id
            ORDER BY l.name;
          SQL

    result = query(sql)

    result.map { |tuple| tuple_to_list_hash(tuple) }
  end

  def create_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(list_id)
    sql = "DELETE FROM lists WHERE id = $1"
    query(sql, list_id)
  end

  def update_list_name(list_id, new_list_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_list_name, list_id)
  end

  def create_todo(list_id, todo)
    sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2)"
    query(sql, list_id, todo)
  end

  def delete_todo(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2"
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, updated_status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3"
    query(sql, updated_status, todo_id, list_id)
  end

  def mark_all_todos_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  def all_todos_for_a_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"

    result = query(sql, list_id)

    result.reduce([]) do |arr, tuple|
      arr << { id: tuple["id"].to_i,
               name: tuple["name"],
               completed: tuple["completed"] == "t" }
    end
  end

  private

  def tuple_to_list_hash(tuple)
    { id: tuple["id"].to_i,
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining_count: tuple["todos_remaining_count"].to_i }
  end
end
