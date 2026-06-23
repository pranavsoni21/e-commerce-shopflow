import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { api } from '../api'

export default function OrderConfirmation() {
  const { id } = useParams()
  const [order, setOrder] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    api
      .getOrder(id)
      .then(setOrder)
      .catch((err) => setError(err.message))
  }, [id])

  if (error) {
    return (
      <div className="page page-narrow">
        <div className="alert">Couldn't load order — {error}</div>
      </div>
    )
  }

  if (!order) {
    return (
      <div className="page page-narrow">
        <div className="skeleton" style={{ height: 240 }} />
      </div>
    )
  }

  return (
    <div className="page page-narrow">
      <div className="confirm-mark">✓</div>
      <div className="eyebrow">Order placed</div>
      <h1>Thank you</h1>
      <p className="subtext">Your order is confirmed and being processed.</p>

      <div className="order-id">#{String(order.id).padStart(5, '0')}</div>

      <div className="form-card">
        {order.items.map((item) => (
          <div className="summary-row" key={item.id}>
            <span>Product #{item.product_id} × {item.quantity}</span>
            <span>${(item.unit_price * item.quantity).toFixed(2)}</span>
          </div>
        ))}
        <div className="summary-row total">
          <span>Total</span>
          <span>${order.total_amount.toFixed(2)}</span>
        </div>
        <p className="subtext" style={{ marginTop: 16 }}>
          Status: <strong style={{ color: 'var(--signal)' }}>{order.status}</strong>
        </p>
        <p className="subtext" style={{ marginTop: 4 }}>
          Shipping to: {order.shipping_address}
        </p>
      </div>

      <div style={{ marginTop: 24 }}>
        <Link to="/" className="btn-secondary" style={{ display: 'block', textAlign: 'center', padding: '12px' }}>
          Continue shopping
        </Link>
      </div>
    </div>
  )
}
