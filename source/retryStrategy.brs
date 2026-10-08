'**
'* @description HTTP request execution with exponential backoff retry strategy.
'*              Automatically retries failed requests with increasing delays to handle
'*              transient network failures and temporarily unavailable services.
'*
'* @param {String} url The HTTP URL to fetch
'* @param {Integer} maxRetries Maximum number of retry attempts (default: 3)
'* @param {Float} baseDelaySeconds Initial delay in seconds before first retry (default: 1.0)
'* @returns {String} Response body on success, or empty string if all retries exhausted
'*
function httpGetWithRetry(url as string, maxRetries = 3 as integer, baseDelaySeconds = 1.0 as float) as string
    attempt = 0
    lastError = ""
    
    while attempt < maxRetries
        attempt = attempt + 1
        
        ' Create fresh transfer object for each attempt
        transfer = createObject("roUrlTransfer")
        transfer.setUrl(url)
        transfer.enableCookies()
        transfer.setCertificatesFile(Const().SSL_CERTIFICATES_FILE)
        transfer.initClientCertificates()
        
        ' Attempt HTTP GET
        result = transfer.GetToString()
        
        ' Success path — return immediately
        if result <> ""
            if attempt > 1
                print "[RETRY] ✓ Succeeded on attempt " + attempt.toStr()
            end if
            return result
        end if
        
        ' Failure path — calculate exponential backoff delay
        if attempt < maxRetries
            ' Exponential backoff: delay = baseDelay * (2 ^ (attempt - 1))
            ' Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s
            delaySeconds = baseDelaySeconds * (2 ^ (attempt - 1))
            print "[RETRY] ⚠ Attempt " + attempt.toStr() + " failed. Waiting " + delaySeconds.toStr() + "s before retry..."
            
            ' Convert to milliseconds and sleep
            sleep(int(delaySeconds * 1000))
        end if
    end while
    
    ' All retries exhausted
    print "[RETRY] ✗ HTTP request failed after " + maxRetries.toStr() + " attempts: " + url
    return ""
end function

'**
'* @description Helper function to determine if a response indicates a retryable error.
'*              Some errors (e.g., 4xx status codes) should not be retried.
'*
'* @param {String} response HTTP response body
'* @param {Integer} statusCode HTTP status code (if known)
'* @returns {Boolean} True if the error is retryable, false if permanent
'*
function isRetryableError(response as string, statusCode = 0 as integer) as boolean
    ' Empty response = network/timeout error = retryable
    if response = ""
        return true
    end if
    
    ' 5xx errors = server errors = retryable
    if statusCode >= 500 and statusCode < 600
        return true
    end if
    
    ' 429 (rate limit) = retryable
    if statusCode = 429
        return true
    end if
    
    ' 4xx errors (except 429) = client error = not retryable
    if statusCode >= 400 and statusCode < 500
        return false
    end if
    
    ' Default: assume retryable
    return true
end function
