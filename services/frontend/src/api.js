// All requests go through the same-origin ALB/Ingress, which routes
// /api/users, /api/products, /api/orders to the respective backend services.
// This means the frontend never needs to know individual service hostnames.
//
// IMPORTANT: ALB Ingress (unlike nginx-ingress) does NOT rewrite paths by
// default — it forwards the full path as-is. So a request to
// /api/users/register arrives at user-svc as /api/users/register, not
// /api/v1/register. Your FastAPI services currently mount routes under
// /api/v1/*, so paths below are written to match the Ingress prefix
// (/api/users, /api/products, /api/orders) directly. See INGRESS_SETUP.md
// for the two options to reconcile this (rewrite annotation vs. changing
// the FastAPI router prefix).

const BASE = '/api'

async function request(path, options = {}) {
  const token = localStorage.getItem('shopflow_token')

  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...options.headers,
  }

  const res = await fetch(`${BASE}${path}`, { ...options, headers })

  if (!res.ok) {
    let detail = `Request failed (${res.status})`
    try {
      const body = await res.json()
      detail = body.detail || detail
    } catch {
      // response wasn't JSON — keep default message
    }
    throw new Error(detail)
  }

  if (res.status === 204) return null
  return res.json()
}

export const api = {
  // user-svc
  register: (data) =>
    request('/users/register', { method: 'POST', body: JSON.stringify(data) }),

  login: (email, password) => {
    const form = new URLSearchParams()
    form.set('username', email)
    form.set('password', password)
    return fetch(`${BASE}/users/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form,
    }).then(async (res) => {
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.detail || 'Invalid email or password')
      }
      return res.json()
    })
  },

  me: () => request('/users/me'),

  // product-svc
  listProducts: () => request('/products/products'),

  // order-svc
  createOrder: (data) =>
    request('/orders/orders', { method: 'POST', body: JSON.stringify(data) }),

  getOrder: (id) => request(`/orders/orders/${id}`),
}
