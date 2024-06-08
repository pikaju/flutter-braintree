package com.example.flutter_braintree;
import static com.braintreepayments.api.PayPalCheckoutRequest.USER_ACTION_COMMIT;
import static com.braintreepayments.api.PayPalCheckoutRequest.USER_ACTION_DEFAULT;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import org.json.JSONException;
import org.json.JSONObject;

import com.braintreepayments.api.BraintreeClient;
import com.braintreepayments.api.Card;
import com.braintreepayments.api.CardClient;
import com.braintreepayments.api.CardNonce;
import com.braintreepayments.api.CardTokenizeCallback;
import com.braintreepayments.api.PayPalAccountNonce;
import com.braintreepayments.api.PayPalCheckoutRequest;
import com.braintreepayments.api.PayPalClient;
import com.braintreepayments.api.PayPalListener;
import com.braintreepayments.api.PayPalPaymentIntent;
import com.braintreepayments.api.PayPalRequest;
import com.braintreepayments.api.PayPalVaultRequest;
import com.braintreepayments.api.PaymentMethodNonce;
import com.braintreepayments.api.PostalAddress;
import com.braintreepayments.api.UserCanceledException;


import java.util.HashMap;
import java.util.Objects;

public class FlutterBraintreeCustom extends AppCompatActivity implements PayPalListener {
    private BraintreeClient braintreeClient;
    private PayPalClient payPalClient;
    private Boolean started = false;
    private long creationTimestamp = -1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        creationTimestamp = System.currentTimeMillis();

        setContentView(R.layout.activity_flutter_braintree_custom);
        try {
            Intent intent = getIntent();
            String returnUrlScheme = (getPackageName() + ".return.from.braintree").replace("_", "").toLowerCase();
            braintreeClient = new BraintreeClient(this, intent.getStringExtra("authorization"), returnUrlScheme);

            String type = intent.getStringExtra("type");
            if (type.equals("tokenizeCreditCard")) {
                tokenizeCreditCard();
            } else if (type.equals("requestPaypalNonce")) {
                payPalClient = new PayPalClient(this, braintreeClient);
                payPalClient.setListener(this);
                requestPaypalNonce();

            } else {
                throw new Exception("Invalid request type: " + type);
            }
        } catch (Exception e) {
            Intent result = new Intent();
            result.putExtra("error", e);
            setResult(2, result);
            finish();
            return;
        }
    }

    @Override
    protected void onNewIntent(Intent newIntent) {
        super.onNewIntent(newIntent);
        setIntent(newIntent);
    }

//    @Override
//    protected void onStart() {
//        super.onStart();
//    }

//    @Override
//    protected void onResume() {
//        super.onResume();
//    }

    protected void tokenizeCreditCard() {
        Intent intent = getIntent();
        Card card = new Card();
        card.setExpirationMonth(intent.getStringExtra("expirationMonth"));
        card.setExpirationYear(intent.getStringExtra("expirationYear"));
        card.setCvv(intent.getStringExtra("cvv"));
        card.setCardholderName(intent.getStringExtra("cardholderName"));
        card.setNumber(intent.getStringExtra("cardNumber"));


        CardClient cardClient = new CardClient(braintreeClient);
        CardTokenizeCallback callback = (cardNonce, error) -> {
            if(cardNonce != null){
                onPaymentMethodNonceCreated(cardNonce);
            }
            if(error != null){
                onError(error);
            }
        };
        cardClient.tokenize(card, callback);
    }

    protected void requestPaypalNonce() {
        Intent intent = getIntent();
        if (intent.getStringExtra("amount") == null) {
            // Vault flow
            PayPalVaultRequest vaultRequest = new PayPalVaultRequest();
            vaultRequest.setDisplayName(intent.getStringExtra("displayName"));
            vaultRequest.setBillingAgreementDescription(intent.getStringExtra("billingAgreementDescription"));
            payPalClient.tokenizePayPalAccount(this, vaultRequest);
        } else {
            // Checkout flow
            PayPalCheckoutRequest checkOutRequest = new PayPalCheckoutRequest(intent.getStringExtra("amount"));
            checkOutRequest.setCurrencyCode(intent.getStringExtra("currencyCode"));
            checkOutRequest.setDisplayName(intent.getStringExtra("displayName"));
            checkOutRequest.setBillingAgreementDescription(intent.getStringExtra("billingAgreementDescription"));
            checkOutRequest.setShouldRequestBillingAgreement(Objects.requireNonNull(intent.getExtras()).getBoolean("requestBillingAgreement"));
            checkOutRequest.setShippingAddressEditable(Objects.requireNonNull(intent.getExtras()).getBoolean("shippingAddressEditable"));
            checkOutRequest.setShippingAddressRequired(Objects.requireNonNull(intent.getExtras()).getBoolean("shippingAddressRequired"));

            // handles the shipping address override
            if (intent.getStringExtra("shippingAddressOverride") != null) {
                try {
                    JSONObject obj = new JSONObject(intent.getStringExtra("shippingAddressOverride"));
                    PostalAddress shippingAddressOverride = new PostalAddress();
                    shippingAddressOverride.setRecipientName(obj.getString("recipientName"));
                    shippingAddressOverride.setStreetAddress(obj.getString("streetAddress"));
                    shippingAddressOverride.setExtendedAddress(obj.getString("extendedAddress"));
                    shippingAddressOverride.setLocality(obj.getString("locality"));
                    shippingAddressOverride.setCountryCodeAlpha2(obj.getString("countryCodeAlpha2"));
                    shippingAddressOverride.setPostalCode(obj.getString("postalCode"));
                    shippingAddressOverride.setRegion(obj.getString("region"));
                    checkOutRequest.setShippingAddressOverride(shippingAddressOverride);
                } catch (JSONException e) {
                    throw new RuntimeException(e);
                }
            }

            String userAction;
            switch (intent.getStringExtra("payPalPaymentUserAction")) {
                case "commit":
                    userAction = USER_ACTION_COMMIT;
                    break;
                default:
                    userAction = USER_ACTION_DEFAULT;
            }
            checkOutRequest.setUserAction(userAction);

            String paymentIntent;
            switch (intent.getStringExtra("payPalPaymentIntent")) {
                case "order":
                    paymentIntent = PayPalPaymentIntent.ORDER;
                    break;
                case "sale":
                    paymentIntent = PayPalPaymentIntent.SALE;
                    break;
                default:
                    paymentIntent = PayPalPaymentIntent.AUTHORIZE;
            }
            checkOutRequest.setIntent(paymentIntent);

            payPalClient.tokenizePayPalAccount(this, checkOutRequest);
        }
    }

    public void onPaymentMethodNonceCreated(PaymentMethodNonce paymentMethodNonce) {
        HashMap<String, Object> nonceMap = new HashMap<String, Object>();
        nonceMap.put("nonce", paymentMethodNonce.getString());
        nonceMap.put("isDefault", paymentMethodNonce.isDefault());
        if (paymentMethodNonce instanceof PayPalAccountNonce) {
            PayPalAccountNonce paypalAccountNonce = (PayPalAccountNonce) paymentMethodNonce;
            nonceMap.put("paypalPayerId", paypalAccountNonce.getPayerId());
            nonceMap.put("typeLabel", "PayPal");
            nonceMap.put("description", paypalAccountNonce.getEmail());

            nonceMap.put("firstName", paypalAccountNonce.getFirstName());
            nonceMap.put("lastName", paypalAccountNonce.getLastName());
            nonceMap.put("email", paypalAccountNonce.getEmail());

            HashMap<String, Object> billingAddressMap = getResultBillingAddress(paypalAccountNonce);

            nonceMap.put("billingAddress", billingAddressMap);
        }else if(paymentMethodNonce instanceof CardNonce){
            CardNonce cardNonce = (CardNonce) paymentMethodNonce;
            nonceMap.put("typeLabel", cardNonce.getCardType());
            nonceMap.put("description", "ending in ••" + cardNonce.getLastTwo());
        }
        Intent result = new Intent();
        result.putExtra("type", "paymentMethodNonce");
        result.putExtra("paymentMethodNonce", nonceMap);
        setResult(RESULT_OK, result);
        finish();
    }

    @NonNull
    private static HashMap<String, Object> getResultBillingAddress(PayPalAccountNonce paypalAccountNonce) {
        PostalAddress btBillingAddress = paypalAccountNonce.getBillingAddress();
        HashMap<String, Object> billingAddressMap = new HashMap<String, Object>();
        billingAddressMap.put("recipientName",btBillingAddress.getRecipientName());
        billingAddressMap.put("streetAddress",btBillingAddress.getStreetAddress());
        billingAddressMap.put("extendedAddress",btBillingAddress.getExtendedAddress());
        billingAddressMap.put("locality",btBillingAddress.getLocality());
        billingAddressMap.put("countryCodeAlpha2",btBillingAddress.getCountryCodeAlpha2());
        billingAddressMap.put("postalCode",btBillingAddress.getPostalCode());
        billingAddressMap.put("region",btBillingAddress.getRegion());
        return billingAddressMap;
    }

    public void onCancel() {
        setResult(RESULT_CANCELED);
        finish();
    }

    public void onError(Exception error) {
        Intent result = new Intent();
        result.putExtra("error", error);
        setResult(2, result);
        finish();
    }

    @Override
    public void onPayPalSuccess(@NonNull PayPalAccountNonce payPalAccountNonce) {
        onPaymentMethodNonceCreated(payPalAccountNonce);
    }

    @Override
    public void onPayPalFailure(@NonNull Exception error) {
        if (error instanceof UserCanceledException) {
            if(((UserCanceledException) error).isExplicitCancelation() || System.currentTimeMillis() - creationTimestamp > 500)
            {
                // PayPal sometimes sends a UserCanceledException early for no reason: filter it out
                // Otherwise take every cancellation event
                onCancel();
            }
        } else {
            onError(error);
        }
    }
}