// Firebase Configuration
const firebaseConfig = {
    apiKey: "AIzaSyDNWUGVrDRXsI3xbQHhDW8DUFGxY9rVZ8c",
    authDomain: "chronoworks-dcfd6.firebaseapp.com",
    projectId: "chronoworks-dcfd6",
    storageBucket: "chronoworks-dcfd6.appspot.com",
    messagingSenderId: "1041869053699",
    appId: "1:1041869053699:web:a8f4c6e2b0d1f9e8e4a5b6"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();

// Phone number formatting
function formatPhoneNumber(value) {
    if (!value) return value;
    const phoneNumber = value.replace(/[^\d]/g, '');
    const phoneNumberLength = phoneNumber.length;

    if (phoneNumberLength < 4) return phoneNumber;
    if (phoneNumberLength < 7) {
        return `(${phoneNumber.slice(0, 3)}) ${phoneNumber.slice(3)}`;
    }
    return `(${phoneNumber.slice(0, 3)}) ${phoneNumber.slice(3, 6)}-${phoneNumber.slice(6, 10)}`;
}

// Add phone number formatting
document.getElementById('ownerPhone').addEventListener('input', function(e) {
    const x = e.target.value.replace(/\D/g, '').match(/(\d{0,3})(\d{0,3})(\d{0,4})/);
    e.target.value = !x[2] ? x[1] : '(' + x[1] + ') ' + x[2] + (x[3] ? '-' + x[3] : '');
});

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Form submission handler
document.getElementById('registrationForm').addEventListener('submit', async function(e) {
    e.preventDefault();

    const submitBtn = document.getElementById('submitBtn');
    const errorMessage = document.getElementById('errorMessage');
    const successMessage = document.getElementById('successMessage');

    // Hide previous messages
    errorMessage.style.display = 'none';
    successMessage.style.display = 'none';

    // Show loading state
    submitBtn.classList.add('loading');
    submitBtn.textContent = 'Submitting';
    submitBtn.disabled = true;

    try {
        // Get form data
        const formData = {
            businessName: document.getElementById('businessName').value.trim(),
            industry: document.getElementById('industry').value,
            numberOfEmployees: document.getElementById('numberOfEmployees').value,
            address: document.getElementById('address').value.trim(),
            timezone: document.getElementById('timezone').value,
            website: document.getElementById('website').value.trim() || null,
            ownerName: document.getElementById('ownerName').value.trim(),
            ownerEmail: document.getElementById('ownerEmail').value.trim().toLowerCase(),
            ownerPhone: document.getElementById('ownerPhone').value.trim(),
            hrName: document.getElementById('hrName').value.trim() || null,
            hrEmail: document.getElementById('hrEmail').value.trim().toLowerCase() || null,
            status: 'pending',
            submittedAt: firebase.firestore.FieldValue.serverTimestamp(),
            source: 'landing_page'
        };

        // Validate HR email if HR name is provided
        if (formData.hrName && !formData.hrEmail) {
            throw new Error('Please provide an email address for the HR contact.');
        }

        // Validate emails are different if both provided
        if (formData.hrEmail && formData.hrEmail === formData.ownerEmail) {
            throw new Error('HR email must be different from owner email.');
        }

        // Submit to Firestore
        const docRef = await db.collection('registrationRequests').add(formData);

        console.log('Registration submitted with ID:', docRef.id);

        // Show success message
        successMessage.innerHTML = `
            <strong>✅ Registration Submitted Successfully!</strong>
            <p style="margin-top: 10px;">Thank you for your interest in ChronoWorks!</p>
            <p>Your application is being reviewed by our team. You'll receive an email with your login credentials within 24 hours.</p>
            <p style="margin-top: 10px;">Questions? Contact us at <a href="mailto:support@chronoworks.com">support@chronoworks.com</a></p>
        `;
        successMessage.style.display = 'block';

        // Reset form
        this.reset();

        // Scroll to success message
        successMessage.scrollIntoView({ behavior: 'smooth', block: 'center' });

        // Track conversion (if you have analytics)
        if (typeof gtag !== 'undefined') {
            gtag('event', 'conversion', {
                'send_to': 'AW-CONVERSION_ID/CONVERSION_LABEL',
                'value': 1.0,
                'currency': 'USD'
            });
        }

    } catch (error) {
        console.error('Error submitting registration:', error);

        let errorMsg = 'An error occurred while submitting your registration. Please try again.';

        // Handle specific Firebase errors
        if (error.code === 'permission-denied') {
            errorMsg = 'Permission denied. Please refresh the page and try again.';
        } else if (error.message) {
            errorMsg = error.message;
        }

        errorMessage.textContent = errorMsg;
        errorMessage.style.display = 'block';
        errorMessage.scrollIntoView({ behavior: 'smooth', block: 'center' });
    } finally {
        // Reset button state
        submitBtn.classList.remove('loading');
        submitBtn.textContent = 'Start Free Trial';
        submitBtn.disabled = false;
    }
});

// Auto-detect timezone
window.addEventListener('DOMContentLoaded', function() {
    try {
        const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        const timezoneSelect = document.getElementById('timezone');

        // Try to match detected timezone with available options
        const timezoneMap = {
            'America/New_York': 'America/New_York',
            'America/Chicago': 'America/Chicago',
            'America/Denver': 'America/Denver',
            'America/Los_Angeles': 'America/Los_Angeles',
            'America/Phoenix': 'America/Denver',
            'America/Anchorage': 'America/Anchorage',
            'Pacific/Honolulu': 'Pacific/Honolulu'
        };

        if (timezoneMap[timezone]) {
            timezoneSelect.value = timezoneMap[timezone];
        }
    } catch (e) {
        console.log('Could not auto-detect timezone');
    }
});

// Form validation helpers
function validateEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
}

function validatePhone(phone) {
    const cleaned = phone.replace(/\D/g, '');
    return cleaned.length === 10;
}

// Real-time validation
document.getElementById('ownerEmail').addEventListener('blur', function() {
    if (this.value && !validateEmail(this.value)) {
        this.setCustomValidity('Please enter a valid email address');
        this.reportValidity();
    } else {
        this.setCustomValidity('');
    }
});

document.getElementById('hrEmail').addEventListener('blur', function() {
    if (this.value && !validateEmail(this.value)) {
        this.setCustomValidity('Please enter a valid email address');
        this.reportValidity();
    } else {
        this.setCustomValidity('');
    }
});

document.getElementById('ownerPhone').addEventListener('blur', function() {
    const cleaned = this.value.replace(/\D/g, '');
    if (cleaned.length > 0 && cleaned.length !== 10) {
        this.setCustomValidity('Please enter a valid 10-digit phone number');
        this.reportValidity();
    } else {
        this.setCustomValidity('');
    }
});

// Website URL validation
document.getElementById('website').addEventListener('blur', function() {
    if (this.value && !this.value.startsWith('http')) {
        this.value = 'https://' + this.value;
    }
});

console.log('ChronoWorks Registration Page Loaded');
