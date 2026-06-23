import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useAuth } from '../AuthContext'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await login(email, password)
      navigate('/')
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="page page-narrow">
      <div className="eyebrow">Welcome back</div>
      <h1>Log in</h1>
      <p className="subtext">Enter your details to access your account.</p>

      <form className="form-card" onSubmit={handleSubmit}>
        <div className="field">
          <label htmlFor="email">Email</label>
          <input
            id="email"
            type="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>
        <div className="field">
          <label htmlFor="password">Password</label>
          <input
            id="password"
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>

        <button className="btn-primary" type="submit" disabled={loading}>
          {loading ? <span className="spinner" /> : 'Log in'}
        </button>

        {error && <div className="alert">{error}</div>}

        <div className="form-switch">
          New here? <Link to="/register">Create an account</Link>
        </div>
      </form>
    </div>
  )
}
