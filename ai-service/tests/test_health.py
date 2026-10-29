from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_match_scores_similar_text_higher():
    body = {
        "resume_text": "React Node MongoDB developer with Express and TypeScript",
        "job_text": "Looking for a React and Node developer, MongoDB, TypeScript",
    }
    res = client.post("/match", json=body).json()
    assert res["score"] > 0
