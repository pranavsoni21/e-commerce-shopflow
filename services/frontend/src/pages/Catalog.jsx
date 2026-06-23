import { useEffect, useState } from 'react'
import { api } from '../api'
import { useCart } from '../CartContext'

export default function Catalog() {
  const [products, setProducts] = useState(null)
  const [error, setError] = useState('')
  const [addedId, setAddedId] = useState(null)
  const { addItem } = useCart()

  useEffect(() => {
    api
      .listProducts()
      .then(setProducts)
      .catch((err) => setError(err.message))
  }, [])

  const handleAdd = (product) => {
    addItem(product)
    setAddedId(product.id)
    setTimeout(() => setAddedId(null), 900)
  }

  return (
    <div className="page">
      <div className="grid-header">
        <div>
          <div className="eyebrow">Catalog</div>
          <h1>Shop products</h1>
        </div>
        <p className="subtext">{products ? `${products.length} items available` : ''}</p>
      </div>

      {error && <div className="alert">Couldn't load products — {error}</div>}

      {!products && !error && (
        <div className="product-grid">
          {[...Array(6)].map((_, i) => (
            <div className="skeleton" key={i} />
          ))}
        </div>
      )}

      {products && products.length === 0 && (
        <div className="empty-state">
          <h2>No products yet</h2>
          <p className="subtext">Check back soon, or add some via the product-svc API.</p>
        </div>
      )}

      {products && products.length > 0 && (
        <div className="product-grid">
          {products.map((p) => (
            <div className="product-card" key={p.id}>
              <div className="price-tag">${p.price.toFixed(2)}</div>
              <div className="product-name">{p.name}</div>
              <div className="product-desc">{p.description || 'No description provided.'}</div>
              <div className="product-meta">
                <span>{p.category}</span>
                <span>{p.stock} in stock</span>
              </div>
              <button className="btn-add" onClick={() => handleAdd(p)} disabled={p.stock === 0}>
                {addedId === p.id ? 'Added ✓' : p.stock === 0 ? 'Out of stock' : 'Add to cart'}
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
