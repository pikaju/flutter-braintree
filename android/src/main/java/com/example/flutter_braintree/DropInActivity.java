package com.example.flutter_braintree;

import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.braintreepayments.api.DropInClient;
import com.braintreepayments.api.DropInListener;
import com.braintreepayments.api.DropInRequest;
import com.braintreepayments.api.DropInResult;
import com.braintreepayments.api.UserCanceledException;

public class DropInActivity extends AppCompatActivity implements DropInListener{
    private DropInClient dropInClient;
    private Boolean started = false;
    private DropInRequest dropInRequest;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_flutter_braintree_drop_in);
        Intent intent = getIntent();
        String token = intent.getStringExtra("token");
        // DropInClient can also be instantiated with a tokenization key
        this.dropInClient = new DropInClient(this, token);
        // Make sure to register listener in onCreate
        this.dropInClient.setListener(this);

        this.dropInRequest = intent.getParcelableExtra("dropInRequest");

    }

    @Override
    protected void onStart() {
        super.onStart();
        if(this.started){
            return;
        }
        this.started = true;
        this.dropInClient.launchDropIn(this.dropInRequest);
    }

    @Override
    public void onDropInSuccess(@NonNull DropInResult dropInResult) {
        this.started = false;
        Intent result = new Intent();
        result.putExtra("dropInResult", dropInResult);
        setResult(RESULT_OK, result);
        finish();
    }

    @Override
    public void onDropInFailure(@NonNull Exception error) {
        this.started = false;
        if (error instanceof UserCanceledException) {
            setResult(RESULT_CANCELED);
        } else {
            Intent result = new Intent();
            result.putExtra("error", error.getMessage());
            setResult(2, result);
        }
        finish();
    }
}
