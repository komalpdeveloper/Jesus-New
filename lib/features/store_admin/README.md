Store Admin backend wiring

- Models: data/models/{category.dart, product.dart}
- Services: data/services/storage_service.dart
- Repositories: data/repositories/{category_repository.dart, product_repository.dart}
- UI: presentation/admin_pages.dart remains unchanged, now fires repo writes on actions

Notes
- Category limit enforced at 6; names normalized via slug
- Product creation uploads selected images to Firebase Storage at products/{productId}/img_{index}.ext and then updates Firestore doc with URLs
- No banner backend per request
