"""ONE-TIME helper (run on Google Colab or your computer, NOT on GitHub).

Colab: open https://colab.research.google.com -> New notebook -> two cells:
  cell 1:  !pip install -q telethon
  cell 2:  paste this whole file and run it.
It asks for api_id, api_hash, your phone number and the login code Telegram sends
you, then prints (1) the SESSION string and (2) the id of every group you are in.
Put the session in the GitHub secret TELETHON_SESSION and the ids of the groups
you want in TELETHON_CHAT_IDS. NEVER share the session string with anyone.
"""
from telethon.sync import TelegramClient
from telethon.sessions import StringSession

api_id = int(input("api_id: ").strip())
api_hash = input("api_hash: ").strip()

with TelegramClient(StringSession(), api_id, api_hash) as client:
    print("\n=== SESSION (keep secret) ===")
    print(client.session.save())
    print("\n=== Your groups/channels: id  |  name ===")
    for d in client.get_dialogs():
        if d.is_group or d.is_channel:
            print(f"{d.id}  |  {d.name}")
