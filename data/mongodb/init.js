// MongoDB initialization script for sockstore
db = db.getSiblingDB('sockstore');

// Create collections
db.createCollection('products');
db.createCollection('users');
db.createCollection('orders');

// Insert sample data
db.products.insertMany([
  {
    id: "1",
    name: "Sample Sock",
    description: "A comfortable sock",
    price: 15.99,
    category: "socks"
  }
]);

print("Database initialized successfully");
