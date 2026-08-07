import React, { useState, useRef, useEffect } from 'react';
import axios from 'axios';
import ReactMarkdown from 'react-markdown';
import './App.css';

const API_URL = process.env.REACT_APP_API_URL || 'https://your-server.onrender.com';

axios.interceptors.request.use(config => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
}, error => Promise.reject(error));

function App() {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isLoggedIn, setIsLoggedIn] = useState(!!localStorage.getItem('token'));
  const chatEndRef = useRef(null);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleLogin = async () => {
    try {
      const response = await axios.post(`${API_URL}/auth/login`, { username, password });
      localStorage.setItem('token', response.data.access_token);
      localStorage.setItem('user_id', response.data.user_id);
      setIsLoggedIn(true);
      alert('✅ تم تسجيل الدخول بنجاح!');
    } catch (error) {
      alert('❌ فشل تسجيل الدخول: ' + (error.response?.data?.detail || error.message));
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user_id');
    setIsLoggedIn(false);
    setMessages([]);
  };

  const sendMessage = async () => {
    if (!input.trim() || !isLoggedIn) return;
    const userMessage = { role: 'user', content: input };
    setMessages([...messages, userMessage]);
    setInput('');
    setLoading(true);

    try {
      const response = await axios.post(`${API_URL}/ask`, {
        query: input,
        language: 'auto',
        deep_thinking: false,
      });
      const assistantMessage = {
        role: 'assistant',
        content: response.data.response || '⚠️ لا يوجد رد',
      };
      setMessages(prev => [...prev, assistantMessage]);
    } catch (error) {
      if (error.response?.status === 401) {
        localStorage.removeItem('token');
        setIsLoggedIn(false);
        alert('⚠️ انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.');
      } else {
        setMessages(prev => [...prev, {
          role: 'assistant',
          content: `⚠️ خطأ: ${error.message}`,
        }]);
      }
    } finally {
      setLoading(false);
    }
  };

  if (!isLoggedIn) {
    return (
      <div className="login-container">
        <h1>🤖 NEXUS-ULTIMATE</h1>
        <div className="login-box">
          <h2>تسجيل الدخول</h2>
          <input type="text" placeholder="اسم المستخدم" value={username} onChange={(e) => setUsername(e.target.value)} />
          <input type="password" placeholder="كلمة المرور" value={password} onChange={(e) => setPassword(e.target.value)} />
          <button onClick={handleLogin}>دخول</button>
        </div>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <h1>🤖 NEXUS-ULTIMATE</h1>
        <button onClick={handleLogout} style={{ marginLeft: '20px', padding: '5px 15px' }}>تسجيل خروج</button>
      </header>
      <div className="chat-container">
        {messages.map((msg, index) => (
          <div key={index} className={`message ${msg.role}`}>
            <div className="message-content">
              <ReactMarkdown>{msg.content}</ReactMarkdown>
            </div>
          </div>
        ))}
        {loading && <div className="loading">⏳ جاري التفكير...</div>}
        <div ref={chatEndRef} />
      </div>
      <div className="input-container">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
          placeholder="اكتب سؤالك..."
          disabled={loading}
        />
        <button onClick={sendMessage} disabled={loading}>إرسال</button>
      </div>
    </div>
  );
}

export default App;