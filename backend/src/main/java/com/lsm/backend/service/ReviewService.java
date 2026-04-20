package com.lsm.backend.service;

import java.util.List;

import org.springframework.stereotype.Service;

import com.lsm.backend.dto.ProviderReviewReplyRequest;
import com.lsm.backend.dto.ReviewCreateRequest;
import com.lsm.backend.dto.ReviewResponse;
import com.lsm.backend.entity.Booking;
import com.lsm.backend.entity.BookingStatus;
import com.lsm.backend.entity.Review;
import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.entity.User;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.BookingRepository;
import com.lsm.backend.repository.ReviewRepository;
import com.lsm.backend.repository.ServiceEntityRepository;
import com.lsm.backend.repository.UserRepository;

@Service
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final ServiceEntityRepository serviceEntityRepository;

    public ReviewService(
            ReviewRepository reviewRepository,
            BookingRepository bookingRepository,
            UserRepository userRepository,
            ServiceEntityRepository serviceEntityRepository) {
        this.reviewRepository = reviewRepository;
        this.bookingRepository = bookingRepository;
        this.userRepository = userRepository;
        this.serviceEntityRepository = serviceEntityRepository;
    }

    public ReviewResponse createReview(ReviewCreateRequest request) {
        if (request == null || request.getBookingId() == null || request.getUserId() == null || request.getRating() == null) {
            throw new BadRequestException("bookingId, userId and rating are required");
        }

        if (request.getRating() < 1 || request.getRating() > 5) {
            throw new BadRequestException("Rating must be between 1 and 5");
        }

        Booking booking = bookingRepository.findById(request.getBookingId())
                .orElseThrow(() -> new BadRequestException("Booking not found"));

        if (!booking.getUserId().equals(request.getUserId())) {
            throw new BadRequestException("You can review only your own bookings");
        }

        BookingStatus status = booking.getStatus() == null ? BookingStatus.PENDING : booking.getStatus();
        if (status != BookingStatus.COMPLETED) {
            throw new BadRequestException("Review can be submitted only after service completion");
        }

        if (booking.getProviderId() == null) {
            throw new BadRequestException("Provider information is missing for this booking");
        }

        if (reviewRepository.existsByBookingId(booking.getId())) {
            throw new BadRequestException("Review already submitted for this booking");
        }

        Review review = new Review();
        review.setBookingId(booking.getId());
        review.setUserId(booking.getUserId());
        review.setProviderId(booking.getProviderId());
        review.setServiceId(booking.getServiceId());
        review.setRating(request.getRating());
        review.setComment(normalizeNullableText(request.getComment()));

        Review savedReview = reviewRepository.save(review);
        refreshProviderRating(savedReview.getProviderId());

        return toResponse(savedReview);
    }

    public List<ReviewResponse> getProviderReviews(Long providerId) {
        User provider = userRepository.findById(providerId)
                .orElseThrow(() -> new BadRequestException("Provider not found"));

        if (provider.getRole() != Role.PROVIDER) {
            throw new BadRequestException("Only PROVIDER accounts can access provider reviews");
        }

        return reviewRepository.findByProviderIdOrderByCreatedAtDesc(providerId).stream()
                .map(this::toResponse)
                .toList();
    }

    public ReviewResponse replyToReview(Long reviewId, ProviderReviewReplyRequest request) {
        if (request == null || request.getProviderId() == null) {
            throw new BadRequestException("providerId is required");
        }

        String response = normalizeNullableText(request.getResponse());
        if (response == null) {
            throw new BadRequestException("response is required");
        }

        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new BadRequestException("Review not found"));

        if (!review.getProviderId().equals(request.getProviderId())) {
            throw new BadRequestException("You can only reply to your own reviews");
        }

        review.setProviderResponse(response);
        Review savedReview = reviewRepository.save(review);
        return toResponse(savedReview);
    }

    private void refreshProviderRating(Long providerId) {
        List<Review> providerReviews = reviewRepository.findByProviderIdOrderByCreatedAtDesc(providerId);
        int totalReviews = providerReviews.size();
        double averageRating = providerReviews.stream()
                .mapToInt(Review::getRating)
                .average()
                .orElse(0.0);

        User provider = userRepository.findById(providerId)
                .orElseThrow(() -> new BadRequestException("Provider not found"));

        provider.setTotalReviews(totalReviews);
        provider.setRatingAverage(averageRating);
        userRepository.save(provider);
    }

    private ReviewResponse toResponse(Review review) {
        String userName = userRepository.findById(review.getUserId())
                .map(User::getName)
                .orElse(null);

        String serviceName = serviceEntityRepository.findById(review.getServiceId())
                .map(ServiceEntity::getName)
                .orElse(null);

        return new ReviewResponse(
                review.getId(),
                review.getBookingId(),
                review.getUserId(),
                userName,
                review.getProviderId(),
                review.getServiceId(),
                serviceName,
                review.getRating(),
                review.getComment(),
                review.getProviderResponse(),
                review.getCreatedAt() == null ? null : review.getCreatedAt().toString());
    }

    private String normalizeNullableText(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
