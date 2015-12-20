package com.typeclassified.hmm.cssr.state

import breeze.linalg._
import com.typeclassified.hmm.cssr.parse.Leaf
import com.typeclassified.hmm.cssr.shared.Probablistic

import scala.collection.mutable.ArrayBuffer

object EquivalenceClass {
  def apply() = new EquivalenceClass()
}

class EquivalenceClass extends Probablistic {
  var histories: ArrayBuffer[Leaf] = ArrayBuffer()

  def addHistory(h: Leaf): Unit = {
    histories += h
    normalizeAcrossHistories()
  }

  def rmHistory(x: Leaf): Unit = {
    histories = histories.filter(y => y.observed != x.observed)
    normalizeAcrossHistories()
  }

  def normalizeAcrossHistories(): Unit = {
    frequency = histories.foldRight(frequency)((history, totalFreq) => totalFreq :+ history.frequency)

    totalCounts = frequency.foldRight(0d)(_+_).toInt

    distribution = if (totalCounts == 0) DenseVector.zeros(frequency.length) else frequency / totalCounts
  }
}
