import app


def test_root_route():
    tester = app.app.test_client()
    response = tester.get("/")
    assert response.status_code == 200
    assert b"Hello from Flask in Kubernetes!" in response.data
