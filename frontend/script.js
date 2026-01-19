const API_BASE_URL = '';

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('frontend-version').textContent = VERSION;
    loadVersions();
    loadMessages();

    document.getElementById('message-form').addEventListener('submit', handleSubmit);
});

async function loadVersions() {
    try {
        const response = await fetch(`${API_BASE_URL}/version`);
        const data = await response.json();
        document.getElementById('backend-version').textContent = data.version;
        document.getElementById('backend-function-version').textContent = data.function_version;
    } catch (error) {
        console.error('Error loading backend version:', error);
        document.getElementById('backend-version').textContent = 'Error';
        document.getElementById('backend-function-version').textContent = 'Error';
    }
}

async function loadMessages() {
    try {
        const response = await fetch(`${API_BASE_URL}/messages`);
        const messages = await response.json();
        renderMessages(messages);
    } catch (error) {
        console.error('Error loading messages:', error);
    }
}

function renderMessages(messages) {
    const list = document.getElementById('messages-list');
    list.innerHTML = '';
    messages.forEach(msg => {
        const msgDiv = document.createElement('div');
        msgDiv.className = 'message';
        msgDiv.innerHTML = `
            <div class="author">${msg.name}</div>
            <div class="timestamp">${new Date(msg.timestamp).toLocaleString()}</div>
            <div class="text">${msg.message}</div>
        `;
        list.appendChild(msgDiv);
    });
}

async function handleSubmit(event) {
    event.preventDefault();
    const name = document.getElementById('name').value;
    const message = document.getElementById('message').value;

    try {
        const response = await fetch(`${API_BASE_URL}/messages`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ name, message }),
        });
        if (response.ok) {
            document.getElementById('name').value = '';
            document.getElementById('message').value = '';
            loadMessages();
        } else {
            alert('Error submitting message');
        }
    } catch (error) {
        console.error('Error submitting message:', error);
        alert('Error submitting message');
    }
}