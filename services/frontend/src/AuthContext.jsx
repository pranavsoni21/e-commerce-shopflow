import { createContext, useContext, useState, useCallback } from 'react'
import { api } from './api'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [ready, setReady] = useState(false)

  const loadUser = useCallback(async () => {
    const token = localStorage.getItem('shopflow_token')
    if (!token) {
      setReady(true)
      return
    }
    try {
      const me = await api.me()
      setUser(me)
    } catch {
      localStorage.removeItem('shopflow_token')
    } finally {
      setReady(true)
    }
  }, [])

  const login = async (email, password) => {
    const { access_token } = await api.login(email, password)
    localStorage.setItem('shopflow_token', access_token)
    const me = await api.me()
    setUser(me)
  }

  const logout = () => {
    localStorage.removeItem('shopflow_token')
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, ready, login, logout, loadUser }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  return useContext(AuthContext)
}
