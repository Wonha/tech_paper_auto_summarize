libsvm の入力ファイルを作成するスクリプト

1.訓練データとテストデータを作る

フォーマットは以下の通り。

  クラス <タブ> 素性1:重み1 素性2:重み2 ... 

1行は1つのデータを表わす。
「クラス」はデータの分類クラスを表わす。
残りの「素性:重み」の列はデータを表わす素性ベクトル。
「クラス」や「素性」には(タブと:以外の)任意の文字列が使える。


2.訓練データを libsvm のフォーマットに変換する

libsvm では、クラスや素性は番号で表わす必要がある。
libsvm_formatter.prl を使い、
訓練データのファイルを libsvm の入力フォーマットに直す。

  (実行例)
  ./libsvm_formatter.prl --training-mode -v sample.training.txt -o training

  以下の3つが出力される
  training.libsvm は libsvm のフォーマットに変換した訓練データ
  training.cls    はクラスと番号の対応関係の記録
  training.ftr    は素性と番号の対応関係の記録


3.テストデータを libsvm のフォーマットに変換する

テストデータも同様にクラスや素性は番号で表わす必要がある。
ただし、素性は訓練データに出現したもののみを使い、
訓練データに出現しない素性は使用しない。
具体的には、2.で作成される
  クラスと番号の対応関係の記録(training.cls)
  素性と番号の対応関係の記録(training.ftr)
を読み込み、これに登録されてないクラスや素性を除去する。

  (実行例)
  ./libsvm_formatter.prl --test-mode -v sample.test.txt -m training -o test 

  test.libsvm は libsvm のフォーマットに変換したテストデータ


[参考] libsvm の使い方

・訓練
  svm-train というコマンドを使う

  (例)
  svm-train training.libsvm training.model
  training.model が学習されたSVM

・テスト
  svm-predict というコマンドを使う

  (例)
  svm-predict test.libsvm training.model test.output
  test.output がSVMによって予測されたクラス

・パラメタ調整
  grid.py を使ってパラメタ c (cost) と g (gamma) を最適化する

  (例)
  /usr/local/libexec/libsvm/grid.py \
  -svmtrain /usr/local/bin/svm-train \
  -gnuplot /usr/local/bin/gnuplot \
  training.libsvm > training.grid

  training.grid の一番最後の行に
    最適化されたc 最適化されたg 正解率
  の3つの数字が出力される。
  svm-train の実行時に -c と -g オプションでパラメタを指定する。

  grid.py の実行には gnuplot が必要。
  gnuplot がインストールされていないときは nop.sh を指定する。
    /usr/local/libexec/libsvm/grid.py -gnuplot ./nop.sh ...
  nop.sh は何もしないダミーのコマンド。
  gnuplot は最適化の様子をグラフィカルに表示するために使われている
  だけなので、なくてもパラメタの最適化は正常に行える。
