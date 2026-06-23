import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useCart } from '../CartContext'
import { useAuth } from '../AuthContext'
import { api } from '../api'

export default function Cart() {
  const { items, updateQuantity, removeItem, totalPrice, clearCart } = useCart()
  const { user } = useAuth()
  const [address, setAddress] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const handleCheckout = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const order = await api.createOrder({
        user_id: user.id,
        shipping_address: address,
        items: items.map((i) => ({
          product_id: i.product.id,
          quantity: i.quantity,
          unit_price: i.product.price,
        })),
      })
      clearCart()
      navigate(`/order/${order.id}`)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  if (items.length === 0) {
    return (
      <div className="page">
        <div className="eyebrow">Cart</div>
        <h1>Your cart is empty</h1>
        <p className="subtext">Browse the catalog and add something you like.</p>
        <div style={{ marginTop: 24 }}>
          <Link to="/" className="btn-secondary" style={{ display: 'inline-block', padding: '10px 20px' }}>
            Go to catalog
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="page page-narrow">
      <div className="eyebrow">Cart</div>
      <h1>Review your order</h1>

      <div className="cart-list">
        {items.map(({ product, quantity }) => (
          <div className="cart-row" key={product.id}>
            <div>
              <div className="cart-row-name">{product.name}</div>
              <div className="cart-row-meta">${product.price.toFixed(2)} each</div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <div className="qty-controls">
                <button className="qty-btn" onClick={() => updateQuantity(product.id, -1)}>−</button>
                <span>{quantity}</span>
                <button className="qty-btn" onClick={() => updateQuantity(product.id, 1)}>+</button>
              </div>
              <button className="remove-link" onClick={() => removeItem(product.id)}>Remove</button>
            </div>
          </div>
        ))}
      </div>

      <div className="summary-row total">
        <span>Total</span>
        <span>${totalPrice.toFixed(2)}</span>
      </div>

      {!user ? (
        <div className="form-card" style={{ marginTop: 24 }}>
          <p className="subtext" style={{ marginBottom: 16 }}>
            Log in to complete your order.
          </p>
          <Link to="/login" className="btn-primary" style={{ display: 'block', textAlign: 'center' }}>
            Log in to checkout
          </Link>
        </div>
      ) : (
        <form className="form-card" onSubmit={handleCheckout} style={{ marginTop: 24 }}>
          <div className="field">
            <label htmlFor="address">Shipping address</label>
            <input
              id="address"
              type="text"
              placeholder="123 Market Street, Indore, MP"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              required
            />
          </div>
          <button className="btn-primary" type="submit" disabled={loading}>
            {loading ? <span className="spinner" /> : `Place order — $${totalPrice.toFixed(2)}`}
          </button>
          {error && <div className="alert">{error}</div>}
        </form>
      )}
    </div>
  )
}
