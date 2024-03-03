package com.example.flutter_braintree;
import static com.braintreepayments.api.PayPalCheckoutRequest.USER_ACTION_COMMIT;
import static com.braintreepayments.api.PayPalCheckoutRequest.USER_ACTION_DEFAULT;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

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
import com.braintreepayments.api.UserCanceledException;


import java.util.HashMap;

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