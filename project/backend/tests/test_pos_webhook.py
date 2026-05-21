import pytest

@pytest.mark.asyncio
async def test_invalid_pos_api_key(client):
    response = await client.post(
        "/pos/webhook",
        headers={"X-POS-API-Key": "wrong-key"},
        json={
            "terminal_id": "TERM_001",
            "event_type": "purchase",
            "card_identifier": "CARD_12345",
            "purchase_amount": 100.0,
            "idempotency_key": "idem-1",
        },
    )
    assert response.status_code == 401