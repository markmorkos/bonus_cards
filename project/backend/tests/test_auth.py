import pytest

@pytest.mark.asyncio
async def test_register_and_login(client):
    payload = {
        "email": "user1@example.com",
        "password": "secret123",
        "full_name": "User One",
        "phone": "+380001112233",
    }
    register_response = await client.post("/auth/register", json=payload)
    assert register_response.status_code in (200, 201)
    data = register_response.json()
    assert "access_token" in data

    login_response = await client.post(
        "/auth/login",
        data={"username": payload["email"], "password": payload["password"]},
    )
    assert login_response.status_code == 200
    login_data = login_response.json()
    assert "access_token" in login_data