import psycopg2
from typing import List, Dict, Any, Optional

class TaskDatabase:
    def __init__(self, config: Dict[str, Any]) -> None:
        self.config = config

    def get_connection(self):
        return psycopg2.connect(
            host=self.config['db']['host'],
            database=self.config['db']['database'],
            user=self.config['db']['user'],
            password=self.config['db']['password']
        )

    def init_db(self) -> None:
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    title TEXT NOT NULL,
                    status TEXT DEFAULT 'pending',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"Migration error: {e}")

    def get_all_tasks(self) -> List[Dict[str, Any]]:
        conn = self.get_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, title, status, created_at FROM tasks ORDER BY created_at DESC;")
        rows = cur.fetchall()
        tasks = [
            {"id": r[0], "title": r[1], "status": r[2], "created_at": r[3].isoformat()}
            for r in rows
        ]
        cur.close()
        conn.close()
        return tasks

    def add_task(self, title: str) -> int:
        conn = self.get_connection()
        cur = conn.cursor()
        cur.execute("INSERT INTO tasks (title) VALUES (%s) RETURNING id;", (title,))
        new_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        return new_id

    def mark_done(self, task_id: int) -> bool:
        conn = self.get_connection()
        cur = conn.cursor()
        cur.execute("UPDATE tasks SET status = 'done' WHERE id = %s;", (task_id,))
        updated = cur.rowcount > 0
        conn.commit()
        cur.close()
        conn.close()
        return updated

    def is_healthy(self) -> bool:
        try:
            conn = self.get_connection()
            conn.close()
            return True
        except:
            return False