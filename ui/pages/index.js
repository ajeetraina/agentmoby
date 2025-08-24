import { useState } from 'react';
import styles from '../styles/Home.module.css';

export default function Home() {
  const [message, setMessage] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);

  const sendMessage = async () => {
    if (!message.trim()) return;
    
    setLoading(true);
    try {
      const res = await fetch('http://localhost:3001/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message }),
      });
      
      const data = await res.json();
      setResponse(data.response || 'No response');
    } catch (error) {
      setResponse('Error: ' + error.message);
    }
    setLoading(false);
  };

  return (
    <div className={styles.container}>
      <h1 className={styles.title}>🐳 MobyAgent</h1>
      <p className={styles.subtitle}>The Whale that never blinks</p>
      
      <div className={styles.chat}>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Ask MobyAgent something..."
          className={styles.textarea}
        />
        <button 
          onClick={sendMessage} 
          disabled={loading}
          className={styles.button}
        >
          {loading ? 'Thinking...' : 'Send'}
        </button>
        
        {response && (
          <div className={styles.response}>
            <strong>MobyAgent:</strong>
            <p>{response}</p>
          </div>
        )}
      </div>
    </div>
  );
}
