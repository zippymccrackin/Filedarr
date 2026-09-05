import asyncio

clients = []


def broadcast(message, recipients=None):
    for client in tuple(clients if recipients is None else recipients):
        try:
            client.put_nowait(message)
        except asyncio.QueueFull:
            # Close slow streams; EventSource reconnects with a fresh DB snapshot.
            while not client.empty():
                client.get_nowait()
            client.put_nowait(None)
