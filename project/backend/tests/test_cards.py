import pytest

@pytest.mark.asyncio
async def test_create_card(client):
    register_payload = {
        "email": "carduser@example.com",
        "password": "secret123",
        "full_name": "Card User",
    }
    register_response = await client.post("/auth/register", json=register_payload)
    assert register_response.status_code in (200, 201)
    token = register_response.json()["access_token"]

    create_response = await client.post(
        "/cards/create",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert create_response.status_code == 200
    card_data = create_response.json()
    assert card_data["card_number"].startswith("CARD_")
    assert card_data["qr_code_data"].startswith(f"BONUS:{card_data['card_number']}:")