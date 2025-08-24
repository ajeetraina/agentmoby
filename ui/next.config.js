/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    outputFileTracingRoot: undefined,
  },
  env: {
    API_BASE_URL: process.env.API_BASE_URL || 'http://localhost:8000',
  }
}

module.exports = nextConfig
