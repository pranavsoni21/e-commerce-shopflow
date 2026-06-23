import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { api } from '../api'

export default function Register() {
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await api.register({ full_name: fullName, email, password })
      setSuccess(true)
      setTimeout(() => navigate('/login'), 1200)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="page page-narrow">
      <div className="eyebrow">Get started</div>
      <h1>Create account</h1>
      <p className="subtext">Join ShopFlow to start placing orders.</p>

      <form className="form-card" onSubmit={handleSubmit}>
        <div className="field">
          <label htmlFor="fullName">Full name</label>
          <input
            id="fullName"
            type="text"
            placeholder="Jordan Lee"
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            required
          />
        </div>
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
            placeholder="At least 8 characters"
            minLength={8}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>

        <button className="btn-primary" type="submit" disabled={loading || success}>
          {loading ? <span className="spinner" /> : 'Create account'}
        </button>

        {error && <div className="alert">{error}</div>}
        {success && <div className="alert alert-ok">Account created — redirecting to login…</div>}

        <div className="form-switch">
          Already have an account? <Link to="/login">Log in</Link>
        </div>
      </form>
    </div>
  )
}
