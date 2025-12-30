This folder contains Firestore repositories for the Store Admin area.

Collections
- categories (docId auto)
  - name: string
  - slug: string (unique)
  - description: string?
  - order: int
  - isActive: bool
  - createdAt/updatedAt: Timestamp

- products (docId auto)
  - title: string
  - slug: string (unique-ish)
  - description: string
  - price: number
  - imageUrls: string[] (download URLs)
  - categoryId: string (category slug)
  - categoryName: string (denormalized)
  - quantity: int
  - rating: number
  - reviews: int
  - note: string?
  - isActive: bool
  - order: int
  - createdAt/updatedAt: Timestamp

Security rules (sketch)
- Allow read to all
- Allow write only to admin users (Firebase Auth/Custom Claims)
