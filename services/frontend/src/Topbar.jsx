import { Link } from 'react-router-dom'
import { useAuth } from './AuthContext'
import { useCart } from './CartContext'

export default function Topbar() {
  const { user, logout } = useAuth()
  const { totalItems } = useCart()

  return (
    <header className="topbar">
      <Link to="/" className="brand">
        <span className="brand-mark" />
        ShopFlow
      </Link>

      <div className="topbar-actions">
        {user ? (
          <>
            <span className="topbar-link">Hi, {user.full_name.split(' ')[0]}</span>
            <button className="topbar-link" onClick={logout} style={{ background: 'none' }}>
              Log out
            </button>
          </>
        ) : (
          <Link to="/login" className="topbar-link">Log in</Link>
        )}
        <Link to="/cart" className="cart-pill">
          Cart {totalItems > 0 && `(${totalItems})`}
        </Link>
      </div>
    </header>
  )
}
