import { Routes, Route } from 'react-router-dom'
import { useEffect } from 'react'
import { AuthProvider, useAuth } from './AuthContext'
import { CartProvider } from './CartContext'
import Topbar from './Topbar'
import Catalog from './pages/Catalog'
import Login from './pages/Login'
import Register from './pages/Register'
import Cart from './pages/Cart'
import OrderConfirmation from './pages/OrderConfirmation'

function Shell() {
  const { loadUser } = useAuth()

  useEffect(() => {
    loadUser()
  }, [loadUser])

  return (
    <div className="app-shell">
      <Topbar />
      <Routes>
        <Route path="/" element={<Catalog />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/cart" element={<Cart />} />
        <Route path="/order/:id" element={<OrderConfirmation />} />
      </Routes>
      <footer className="footer">ShopFlow — deployed on EKS via ArgoCD</footer>
    </div>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <CartProvider>
        <Shell />
      </CartProvider>
    </AuthProvider>
  )
}
