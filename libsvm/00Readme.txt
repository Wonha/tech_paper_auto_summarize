libsvm �����ϥե������������륹����ץ�

1.�����ǡ����ȥƥ��ȥǡ�������

�ե����ޥåȤϰʲ����̤ꡣ

  ���饹 <����> ����1:�Ť�1 ����2:�Ť�2 ... 

1�Ԥ�1�ĤΥǡ�����ɽ�魯��
�֥��饹�פϥǡ�����ʬ�९�饹��ɽ�魯��
�Ĥ�Ρ�����:�Ťߡפ���ϥǡ�����ɽ�魯�����٥��ȥ롣
�֥��饹�פ�������פˤ�(���֤�:�ʳ���)Ǥ�դ�ʸ���󤬻Ȥ��롣


2.�����ǡ����� libsvm �Υե����ޥåȤ��Ѵ�����

libsvm �Ǥϡ����饹���������ֹ��ɽ�魯ɬ�פ����롣
libsvm_formatter.prl ��Ȥ���
�����ǡ����Υե������ libsvm �����ϥե����ޥåȤ�ľ����

  (�¹���)
  ./libsvm_formatter.prl --training-mode -v sample.training.txt -o training

  �ʲ���3�Ĥ����Ϥ����
  training.libsvm �� libsvm �Υե����ޥåȤ��Ѵ����������ǡ���
  training.cls    �ϥ��饹���ֹ���б��ط��ε�Ͽ
  training.ftr    ���������ֹ���б��ط��ε�Ͽ


3.�ƥ��ȥǡ����� libsvm �Υե����ޥåȤ��Ѵ�����

�ƥ��ȥǡ�����Ʊ�ͤ˥��饹���������ֹ��ɽ�魯ɬ�פ����롣
�������������Ϸ����ǡ����˽и�������ΤΤߤ�Ȥ���
�����ǡ����˽и����ʤ������ϻ��Ѥ��ʤ���
����Ū�ˤϡ�2.�Ǻ��������
  ���饹���ֹ���б��ط��ε�Ͽ(training.cls)
  �������ֹ���б��ط��ε�Ͽ(training.ftr)
���ɤ߹��ߡ��������Ͽ����Ƥʤ����饹�����������롣

  (�¹���)
  ./libsvm_formatter.prl --test-mode -v sample.test.txt -m training -o test 

  test.libsvm �� libsvm �Υե����ޥåȤ��Ѵ������ƥ��ȥǡ���


[����] libsvm �λȤ���

������
  svm-train �Ȥ������ޥ�ɤ�Ȥ�

  (��)
  svm-train training.libsvm training.model
  training.model ���ؽ����줿SVM

���ƥ���
  svm-predict �Ȥ������ޥ�ɤ�Ȥ�

  (��)
  svm-predict test.libsvm training.model test.output
  test.output ��SVM�ˤ�ä�ͽ¬���줿���饹

���ѥ�᥿Ĵ��
  grid.py ��Ȥäƥѥ�᥿ c (cost) �� g (gamma) ���Ŭ������

  (��)
  /usr/local/libexec/libsvm/grid.py \
  -svmtrain /usr/local/bin/svm-train \
  -gnuplot /usr/local/bin/gnuplot \
  training.libsvm > training.grid

  training.grid �ΰ��ֺǸ�ιԤ�
    ��Ŭ�����줿c ��Ŭ�����줿g ����Ψ
  ��3�Ĥο��������Ϥ���롣
  svm-train �μ¹Ի��� -c �� -g ���ץ����ǥѥ�᥿����ꤹ�롣

  grid.py �μ¹Ԥˤ� gnuplot ��ɬ�ס�
  gnuplot �����󥹥ȡ��뤵��Ƥ��ʤ��Ȥ��� nop.sh ����ꤹ�롣
    /usr/local/libexec/libsvm/grid.py -gnuplot ./nop.sh ...
  nop.sh �ϲ��⤷�ʤ����ߡ��Υ��ޥ�ɡ�
  gnuplot �Ϻ�Ŭ�����ͻҤ򥰥�ե������ɽ�����뤿��˻Ȥ��Ƥ���
  �����ʤΤǡ��ʤ��Ƥ�ѥ�᥿�κ�Ŭ��������˹Ԥ��롣
