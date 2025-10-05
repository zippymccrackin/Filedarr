import app.state as state

def test_clients_is_empty_list():
    assert isinstance(state.clients, list)