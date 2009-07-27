#!/usr/bin/php
<?php

if (strlen($argv[1]) > 0) {
  $url = "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=".rawurlencode($argv[1]);

  // sendRequest
  // note how referer is set manually
  $ch = curl_init();
  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
  curl_setopt($ch, CURLOPT_REFERER, "mail://jeff.welling@gmail.com");
  $body = curl_exec($ch);
  curl_close($ch);

  // now, process the JSON string
  $json = json_decode($body);
  // now have some fun with the results...

  $storage = array();
  foreach ($json->responseData->results as $i => $object) {
  $storage[$i] = get_object_vars($object);
  }

  $it=0;
  foreach ($storage as $i => $arry) {
    $int = 0;
    $temp=array();
    foreach ($arry as $name => $item) {
      $temp[$int++]= $name."<:>".$item;
    }
    $storage[$i] = array();
    $storage[$i] = $temp;
  }

  foreach ($storage as $i => $arry) {
    $storage[$i] = implode("<level2>", $arry);
  }

  print(implode("<level1>", $storage));
}
?>
