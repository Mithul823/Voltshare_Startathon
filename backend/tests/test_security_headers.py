from fastapi.testclient import TestClient


DOCS_CSP_PARTS = [
    "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net",
    "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net",
    "img-src 'self' data: https://fastapi.tiangolo.com",
    "font-src 'self' data: https://cdn.jsdelivr.net",
    "connect-src 'self'",
]


def test_docs_returns_200_with_documentation_csp(client: TestClient) -> None:
    response = client.get("/docs")

    assert response.status_code == 200
    csp = response.headers["Content-Security-Policy"]
    for expected in DOCS_CSP_PARTS:
        assert expected in csp


def test_openapi_json_returns_200_with_documentation_csp(client: TestClient) -> None:
    response = client.get("/openapi.json")

    assert response.status_code == 200
    assert "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net" in response.headers["Content-Security-Policy"]


def test_normal_api_routes_retain_strict_csp(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.headers["Content-Security-Policy"] == "default-src 'self'"
