from flask import Flask, render_template, request, jsonify
from google.adk.runners import InMemoryRunner
from google.genai import types
import asyncio
import os

app = Flask(__name__)


runner = None
character_exists = os.path.exists('character.py')

if character_exists:
    import character
    runner = InMemoryRunner(
        agent=character.root_agent,
        app_name="Demo App",
    )

@app.route('/')
def index():
    return render_template('index.html')


@app.route('/chat', methods=['POST'])
async def chat():
    user_message = request.json.get('message')
    session_id = request.json.get('session_id', 'default_session')

    if not character_exists:
        return jsonify({'response': user_message})

    # Retrieve or create session dynamically
    adk_session = await runner.session_service.get_session(
        app_name=runner.app_name, user_id="inapp_user", session_id=session_id
    )
    if adk_session is None:
        adk_session = await runner.session_service.create_session(
            app_name=runner.app_name, user_id="inapp_user", session_id=session_id
        )

    content = types.Content(role="user", parts=[types.Part(text=user_message)])
    response_text = ""
    async for event in runner.run_async(
        user_id=adk_session.user_id,
        session_id=adk_session.id,
        new_message=content,
    ):
        if event.content and event.content.parts and event.content.parts[0].text:
            response_text += event.content.parts[0].text

    return jsonify({'response': response_text})


if __name__ == '__main__':
    app.run(debug=True)
