from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Sum
from .models import Vendor
from .models_promo_category import Promotion, VendorCategory
from .serializers import PromotionSerializer, VendorCategorySerializer
from customer_app.models import Order

class VendorAnalyticsView(APIView):
    def get(self, request, vendor_id):
        try:
            total_orders = Order.objects.filter(vendor__vendor_id=vendor_id).count()
            total_revenue = Order.objects.filter(vendor__vendor_id=vendor_id).aggregate(Sum('total_price'))['total_price__sum'] or 0
            pending_orders = Order.objects.filter(vendor__vendor_id=vendor_id, status='Pending').count()
            completed_orders = Order.objects.filter(vendor__vendor_id=vendor_id, status='Fulfilled').count()
            # Find most popular item (by count in items JSON)
            orders = Order.objects.filter(vendor__vendor_id=vendor_id)
            item_count = {}
            for order in orders:
                for item in order.items:
                    name = item.get('name')
                    if name:
                        item_count[name] = item_count.get(name, 0) + item.get('quantity', 1)
            popular_item = max(item_count, key=item_count.get) if item_count else ''
            data = {
                "total_orders": total_orders,
                "total_revenue": float(total_revenue),
                "pending_orders": pending_orders,
                "completed_orders": completed_orders,
                "popular_item": popular_item,
            }
            return Response(data)
        except Exception as e:
            return Response({"error": str(e)}, status=500)

class VendorPromotionsView(APIView):
    def get(self, request, vendor_id):
        promos = Promotion.objects.filter(vendor__vendor_id=vendor_id).order_by('-created_at')
        serializer = PromotionSerializer(promos, many=True)
        return Response(serializer.data)

    def post(self, request, vendor_id):
        try:
            vendor = Vendor.objects.get(vendor_id=vendor_id)
        except Vendor.DoesNotExist:
            return Response({'error': 'Vendor not found'}, status=404)
        data = request.data.copy()
        data['vendor'] = vendor.id
        serializer = PromotionSerializer(data=data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=201)
        return Response({'error': serializer.errors}, status=400)

    def put(self, request, vendor_id, promo_id):
        try:
            promo = Promotion.objects.get(id=promo_id, vendor__vendor_id=vendor_id)
        except Promotion.DoesNotExist:
            return Response({'error': 'Promotion not found'}, status=404)
        serializer = PromotionSerializer(promo, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response({'error': serializer.errors}, status=400)

    def delete(self, request, vendor_id, promo_id):
        try:
            promo = Promotion.objects.get(id=promo_id, vendor__vendor_id=vendor_id)
        except Promotion.DoesNotExist:
            return Response({'error': 'Promotion not found'}, status=404)
        promo.delete()
        return Response({'message': 'Promotion deleted successfully'})

class VendorCategoryView(APIView):
    def get(self, request, vendor_id):
        cats = VendorCategory.objects.filter(vendor__vendor_id=vendor_id).order_by('-created_at')
        serializer = VendorCategorySerializer(cats, many=True)
        return Response(serializer.data)

    def post(self, request, vendor_id):
        try:
            vendor = Vendor.objects.get(vendor_id=vendor_id)
        except Vendor.DoesNotExist:
            return Response({'error': 'Vendor not found'}, status=404)
        data = request.data.copy()
        data['vendor'] = vendor.id
        serializer = VendorCategorySerializer(data=data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=201)
        return Response({'error': serializer.errors}, status=400)

    def put(self, request, vendor_id, category_id):
        try:
            cat = VendorCategory.objects.get(id=category_id, vendor__vendor_id=vendor_id)
        except VendorCategory.DoesNotExist:
            return Response({'error': 'Category not found'}, status=404)
        serializer = VendorCategorySerializer(cat, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response({'error': serializer.errors}, status=400)

    def delete(self, request, vendor_id, category_id):
        try:
            cat = VendorCategory.objects.get(id=category_id, vendor__vendor_id=vendor_id)
        except VendorCategory.DoesNotExist:
            return Response({'error': 'Category not found'}, status=404)
        cat.delete()
        return Response({'message': 'Category deleted successfully'})
