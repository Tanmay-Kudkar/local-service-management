package com.lsm.backend.controller;

import java.time.LocalDate;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.lsm.backend.dto.ProviderEarningsResponse;
import com.lsm.backend.service.ProviderInsightsService;

@RestController
@RequestMapping("/providers")
public class ProviderInsightsController {

    private final ProviderInsightsService providerInsightsService;

    public ProviderInsightsController(ProviderInsightsService providerInsightsService) {
        this.providerInsightsService = providerInsightsService;
    }

    @GetMapping("/{providerId}/earnings")
    public ResponseEntity<ProviderEarningsResponse> getProviderEarnings(
            @PathVariable Long providerId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(providerInsightsService.getProviderEarnings(providerId, fromDate, toDate));
    }
}
