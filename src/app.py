import yaml
from flask import Flask, request, jsonify, render_template_string
from typing import Any, Dict, Union
from database import TaskDatabase

app = Flask(__name__)
CONFIG_PATH = "/etc/mywebapp/config.yaml"

def load_config() -> Dict[str, Any]:
    with open(CONFIG_PATH, "r") as f:
        return yaml.safe_load(f)

# Ініціалізація
config = load_config()
db = TaskDatabase(config)

def render_result(data: Any, html_template: str) -> Any:
    if request.headers.get('Accept') == 'application/json':
        return jsonify(data)
    return render_template_string(html_template, data=data)

@app.route('/', methods=['GET'])
def root():
    return """
    <h1>Task Tracker API</h1>
    <ul>
        <li>GET /tasks - List all tasks</li>
        <li>POST /tasks - Create task (JSON: {"title": "..."})</li>
        <li>POST /tasks/&lt;id&gt;/done - Complete task</li>
    </ul>
    """

@app.route('/tasks', methods=['GET'])
def get_tasks():
    tasks = db.get_all_tasks()
    html = """
    <h2>Tasks</h2>
    <table border="1">
        <tr><th>ID</th><th>Title</th><th>Status</th><th>Created At</th></tr>
        {% for t in data %}
        <tr><td>{{t.id}}</td><td>{{t.title}}</td><td>{{t.status}}</td><td>{{t.created_at}}</td></tr>
        {% endfor %}
    </table>
    """
    return render_result(tasks, html)

@app.route('/tasks', methods=['POST'])
def create():
    title = request.json.get('title') if request.is_json else request.form.get('title')
    if not title: return "Title required", 400
    new_id = db.add_task(title)
    return jsonify({"id": new_id, "status": "created"}), 201

@app.route('/tasks/<int:id>/done', methods=['POST'])
def done(id: int):
    if db.mark_done(id):
        return jsonify({"status": "done"}), 200
    return "Not found", 404

# Health Checks 
@app.route('/health/alive', methods=['GET'])
def alive(): return "OK", 200

@app.route('/health/ready', methods=['GET'])
def ready():
    return ("OK", 200) if db.is_healthy() else ("DB connection failed", 500)

if __name__ == '__main__':
    db.init_db() # Виконання міграції перед запуском 
    app.run(host='127.0.0.1', port=config['app']['port'])